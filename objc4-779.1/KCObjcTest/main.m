//
//  main.m
//  KCObjcTest
//
//  Created by Cooci on 2020/3/5.
//

#import <Foundation/Foundation.h>
#import "Person.h"
#include "runtime.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        
        Person *person = [Person alloc];
//        NSLog(@"1- %zd",class_getInstanceSize([Person class]));
//        NSLog(@"2- %lu %lu %lu",(uintptr_t)[person class],(uintptr_t)person,(uintptr_t)[Person class]);
        
    }
    return 0;
}
