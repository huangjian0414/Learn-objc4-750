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
#import "Student.h"
#import "NewStudent.h"
#import "NewStudent1.h"

//#import "runtime.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        //NSObject *obj = [[NSObject alloc]init];
//        Person *per = [[Person alloc]init];
//        Student *stu = [[Student alloc]init];
        [NewStudent1 new];
        
        Person *person = [Person new];
        person.isDealToken = @"haha";
        person.isDealToken = NULL;
//        Class cls = object_getClass(person);
        //[person sayYes];
        [person sayNo];
        
    }
    return 0;
}
