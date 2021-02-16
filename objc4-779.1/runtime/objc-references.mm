/*
 * Copyright (c) 2004-2007 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
  Implementation of the weak / associative references for non-GC mode.
*/


#include "objc-private.h"
#include <objc/message.h>
#include <map>
#include "DenseMapExtras.h"

// expanded policy bits.

enum {
    OBJC_ASSOCIATION_SETTER_ASSIGN      = 0,
    OBJC_ASSOCIATION_SETTER_RETAIN      = 1,
    OBJC_ASSOCIATION_SETTER_COPY        = 3,            // NOTE:  both bits are set, so we can simply test 1 bit in releaseValue below.
    OBJC_ASSOCIATION_GETTER_READ        = (0 << 8),
    OBJC_ASSOCIATION_GETTER_RETAIN      = (1 << 8),
    OBJC_ASSOCIATION_GETTER_AUTORELEASE = (2 << 8)
};

spinlock_t AssociationsManagerLock;

namespace objc {

class ObjcAssociation {
    uintptr_t _policy;
    id _value;
public:
    ObjcAssociation(uintptr_t policy, id value) : _policy(policy), _value(value) {}
    ObjcAssociation() : _policy(0), _value(nil) {}
    ObjcAssociation(const ObjcAssociation &other) = default;
    ObjcAssociation &operator=(const ObjcAssociation &other) = default;
    ObjcAssociation(ObjcAssociation &&other) : ObjcAssociation() {
        swap(other);
    }

    inline void swap(ObjcAssociation &other) {
        std::swap(_policy, other._policy);
        std::swap(_value, other._value);
    }

    inline uintptr_t policy() const { return _policy; }
    inline id value() const { return _value; }

    inline void acquireValue() {
        if (_value) {
            switch (_policy & 0xFF) {
            case OBJC_ASSOCIATION_SETTER_RETAIN:
                _value = objc_retain(_value);
                break;
            case OBJC_ASSOCIATION_SETTER_COPY:
                _value = ((id(*)(id, SEL))objc_msgSend)(_value, @selector(copy));
                break;
            }
        }
    }

    inline void releaseHeldValue() {
        if (_value && (_policy & OBJC_ASSOCIATION_SETTER_RETAIN)) {
            objc_release(_value);
        }
    }

    inline void retainReturnedValue() {
        if (_value && (_policy & OBJC_ASSOCIATION_GETTER_RETAIN)) {
            objc_retain(_value);
        }
    }

    inline id autoreleaseReturnedValue() {
        if (slowpath(_value && (_policy & OBJC_ASSOCIATION_GETTER_AUTORELEASE))) {
            return objc_autorelease(_value);
        }
        return _value;
    }
};

typedef DenseMap<const void *, ObjcAssociation> ObjectAssociationMap;
typedef DenseMap<DisguisedPtr<objc_object>, ObjectAssociationMap> AssociationsHashMap;

// class AssociationsManager manages a lock / hash table singleton pair.
// Allocating an instance acquires the lock

class AssociationsManager {
    using Storage = ExplicitInitDenseMap<DisguisedPtr<objc_object>, ObjectAssociationMap>;
    static Storage _mapStorage;///静态变量，全局唯一

public:
    AssociationsManager()   { AssociationsManagerLock.lock(); }
    ~AssociationsManager()  { AssociationsManagerLock.unlock(); }

    AssociationsHashMap &get() {
        return _mapStorage.get();
    }

    static void init() {
        _mapStorage.init();
    }
};

AssociationsManager::Storage AssociationsManager::_mapStorage;

} // namespace objc

using namespace objc;

void
_objc_associations_init()
{
    AssociationsManager::init();
}

id
_object_get_associative_reference(id object, const void *key)
{
    ObjcAssociation association{};

    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.get());
        /// 通过object 找到 iterator 迭代器
        AssociationsHashMap::iterator i = associations.find((objc_object *)object);
        if (i != associations.end()) {
            // 获取ObjectAssociationMap
            ObjectAssociationMap &refs = i->second;
            //根据key查找ObjectAssociationMap
            ObjectAssociationMap::iterator j = refs.find(key);
            if (j != refs.end()) {
                //获取ObjectAssociation
                association = j->second;
                //根据当前的value以及关联策略policy进行判断是否需要对当前的值进行retain
                association.retainReturnedValue();
            }
        }
    }
    //返回value 内部会根据当前的value以及关联策略policy进行判断是否需要对当前的值进行autorelease
    return association.autoreleaseReturnedValue();
}

void
_object_set_associative_reference(id object, const void *key, id value, uintptr_t policy)
{
    // This code used to work when nil was passed for object and key. Some code
    // probably relies on that to not crash. Check and handle it explicitly.
    // rdar://problem/44094390
    if (!object && !value) return;

    if (object->getIsa()->forbidsAssociatedObjects())
        _objc_fatal("objc_setAssociatedObject called on instance (%p) of class %s which does not allow associated objects", object, object_getClassName(object));
    /// 通过object 生成 DisguisedPtr ，后面作为AssociationsHashMap 的key
    DisguisedPtr<objc_object> disguised{(objc_object *)object};
    ObjcAssociation association{policy, value};

    // retain the new value (if any) outside the lock.
    //根据策略类型进行处理
    association.acquireValue();

    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.get());

        if (value) {
            /// 根据disguised 查找 返回pair 类对
            auto refs_result = associations.try_emplace(disguised, ObjectAssociationMap{});
            if (refs_result.second) { //yes 即没有找到 ，就是第一次建立关联
                /* it's the first association we make */
                /// 将isa 的has_assoc标志位 设为true
                object->setHasAssociatedObjects();
            }

            /* establish or replace the association */
            // 得到一个空的桶
            auto &refs = refs_result.first->second;
            // 查找当前的key是否有association关联对象
            auto result = refs.try_emplace(key, std::move(association));
            if (!result.second) { // 找到了，则swap交换 ，没找到即已经插入了
                association.swap(result.first->second);
            }
        } else {// value 为空· 移除关联
            /// 通过disguised 找到 iterator 迭代器
            auto refs_it = associations.find(disguised);
            if (refs_it != associations.end()) {
                auto &refs = refs_it->second;
                auto it = refs.find(key);
                if (it != refs.end()) {
                    /// 交换 原来ObjectAssociation里的value 置为空
                    association.swap(it->second);
                    /// 从map里擦除
                    refs.erase(it);//清理ObjectAssociationMap的it
                    if (refs.size() == 0) {/// 没有关联了
                        associations.erase(refs_it);// 清理AssociationsHashMap的refs_it
                    }
                }
            }
        }
    }

    // release the old value (outside of the lock).
    /// 释放旧值
    association.releaseHeldValue();
}

// Unlike setting/getting an associated reference,
// this function is performance sensitive because of
// raw isa objects (such as OS Objects) that can't track
// whether they have associated objects.
void
_object_remove_assocations(id object)
{
    ObjectAssociationMap refs{};

    {
        AssociationsManager manager;
        AssociationsHashMap &associations(manager.get());
        AssociationsHashMap::iterator i = associations.find((objc_object *)object);
        if (i != associations.end()) {
            refs.swap(i->second);
            associations.erase(i);
        }
    }

    // release everything (outside of the lock).
    for (auto &i: refs) {
        i.second.releaseHeldValue();
    }
}
