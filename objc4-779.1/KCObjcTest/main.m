//
//  main.m
//  KCObjcTest
//
//  Created by Cooci on 2020/3/5.
//

#import <Foundation/Foundation.h>
#import "Person.h"
#import "Person+HJJJJJ.h"
#import "Person+HTTTTT.h"
#import "runtime.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        
        Person *person = [Person new];
        Class cls = object_getClass(person);
        //[person sayYes];
        [person sayNo];
        
    }
    return 0;
}
