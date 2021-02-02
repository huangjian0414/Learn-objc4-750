//
//  Person+HJJJJJ.m
//  KCObjcTest
//
//  Created by huangjian on 2020/8/3.
//

#import "Person+HJJJJJ.h"
#import "runtime.h"

@implementation Person (HJJJJJ)
//+(void)load{
//    NSLog(@"HJJJJ Load");
//}

-(void)sayYes{
    NSLog(@"HJJJJ sayYes");
}
-(void)sayNo{
    //NSLog(@"HJJJJ sayNo");
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList([self class], &methodCount);
    
    IMP lastIMP = nil;
    for (NSInteger i = 0; i < methodCount; ++i) {
        Method method = methodList[i];
        NSString *selName = NSStringFromSelector(method_getName(method));
        if ([@"sayYes" isEqualToString:selName]) {
            lastIMP = method_getImplementation(method);
            ((void(*)(void))lastIMP)();
        }
    }
}
@end
