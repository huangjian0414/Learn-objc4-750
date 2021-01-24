//
//  Person.h
//  KCObjcTest
//
//  Created by huangjian on 2020/7/2.
//

#import <Foundation/Foundation.h>
#import "Human.h"
NS_ASSUME_NONNULL_BEGIN

@interface Person : Human
//{
//    int _age;
//    int _age1;
//    int _age2;
//}
//@property(nonatomic,assign)BOOL sex;
-(void)sayYes;
+(void)sayHello;
@end

NS_ASSUME_NONNULL_END
