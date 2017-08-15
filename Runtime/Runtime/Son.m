//
//  Son.m
//  Runtime
//
//  Created by Thinkive on 2017/8/14.
//  Copyright © 2017年 Teo. All rights reserved.
//

#import "Son.h"
#import <objc/runtime.h>

@implementation Son

- (id)init{
    if ([super init]) {
        NSLog(@"%@",NSStringFromClass([self class]));
        NSLog(@"%@",NSStringFromClass([super class]));
//        objc_msgSendSuper();
        
    }
    return self;
}

- (Class)class {
    return object_getClass(self);
}

/**
 self和super的区别：

 self是类的一个隐藏参数，每个方法的实现的第一个参数即为self。

 super并不是隐藏参数，它实际上只是一个”编译器标示符”，它负责告诉编译器，当调用方法时，去调用父类的方法，而不是本类中的方法。

 在调用[super class]的时候，runtime会去调用objc_msgSendSuper方法，而不是objc_msgSend
 
 在objc_msgSendSuper方法中，第一个参数是一个objc_super的结构体，这个结构体里面有两个变量，一个是接收消息的receiver，一个是当前类的父类super_class。
 
 objc_msgSendSuper的工作原理应该是这样的:
 从objc_super结构体指向的superClass父类的方法列表开始查找selector，找到后以objc->receiver去调用父类的这个selector。注意，最后的调用者是objc->receiver，而不是super_class！
 
 由于找到了父类NSObject里面的class方法的IMP，又因为传入的入参objc_super->receiver = self。self就是son，调用class，所以父类的方法class执行IMP之后，输出还是son，最后输出两个都一样，都是输出son。
 
 
**/

@end
