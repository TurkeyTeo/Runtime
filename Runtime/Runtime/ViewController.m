//
//  ViewController.m
//  Runtime
//
//  Created by Thinkive on 2017/8/11.
//  Copyright © 2017年 Teo. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "Son.h"


@interface Sark : NSObject

@property (nonatomic, copy) NSString *name;

- (void)speak;

@end

@implementation Sark

- (void)speak {
    NSLog(@"my name's %@", self.name);
}

@end

@interface ViewController ()

@property (nonatomic, copy) NSString *name;

@end

@implementation ViewController



- (void)runtimeTest{
    NSLog(@"**************************************");
    
//    这几道题的解答来自冰霜的简书：http://www.jianshu.com/p/9d649ce6d0b8
    
    //    1.
    Son *son = [[Son alloc] init];
    
    //    2.
    BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];
    BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];
    BOOL res3 = [(id)[Sark class] isKindOfClass:[Sark class]];
    BOOL res4 = [(id)[Sark class] isMemberOfClass:[Sark class]];
    
    NSLog(@"%d %d %d %d", res1, res2, res3, res4);
    
    /**
     + (BOOL)isKindOfClass:(Class)cls方法内部，会先去获得object_getClass的类，而object_getClass的源码实现是去调用当前类的obj->getIsa()，最后在ISA()方法中获得meta class的指针。
     
     接着在isKindOfClass中有一个循环，先判断class是否等于meta class，不等就继续循环判断是否等于super class，不等再继续取super class，如此循环下去。
     
     [NSObject class]执行完之后调用isKindOfClass，第一次判断先判断NSObject 和 NSObject的meta class是否相等，之前讲到meta class的时候放了一张很详细的图，从图上我们也可以看出，NSObject的meta class与本身不等。接着第二次循环判断NSObject与meta class的superclass是否相等。还是从那张图上面我们可以看到：Root class(meta) 的superclass 就是 Root class(class)，也就是NSObject本身。所以第二次循环相等，于是第一行res1输出应该为YES。
     
     同理，[Sark class]执行完之后调用isKindOfClass，第一次for循环，Sark的Meta Class与[Sark class]不等，第二次for循环，Sark Meta Class的super class 指向的是 NSObject Meta Class， 和 Sark Class不相等。第三次for循环，NSObject Meta Class的super class指向的是NSObject Class，和 Sark Class 不相等。第四次循环，NSObject Class 的super class 指向 nil， 和 Sark Class不相等。第四次循环之后，退出循环，所以第三行的res3输出为NO。
     
     如果把这里的Sark改成它的实例对象，[sark isKindOfClass:[Sark class]，那么此时就应该输出YES了。因为在isKindOfClass函数中，判断sark的isa指向是否是自己的类Sark，第一次for循环就能输出YES了。
     
     isMemberOfClass的源码实现是拿到自己的isa指针和自己比较，是否相等。
     第二行isa 指向 NSObject 的 Meta Class，所以和 NSObject Class不相等。第四行，isa指向Sark的Meta Class，和Sark Class也不等，所以第二行res2和第四行res4都输出NO。
     
     **/
    
    
    //    3.
    id cls = [Sark class];
    void *obj = &cls;
    [(__bridge id)obj speak];
 
    
//    NSLog(@"ViewController = %@ , 地址 = %p", self, &self);
//    
//    id cls = [Sark class];
//    NSLog(@"Sark class = %@ 地址 = %p", cls, &cls);
//    
//    void *obj = &cls;
//    NSLog(@"Void *obj = %@ 地址 = %p", obj,&obj);
//    
//    [(__bridge id)obj speak];
//    
//    Sark *sark = [[Sark alloc]init];
//    NSLog(@"Sark instance = %@ 地址 = %p",sark,&sark);
//    
//    [sark speak];
    
    
    
    /**
     self是类的一个隐藏参数，每个方法的实现的第一个参数即为self。
     
     当[receiver message]调用方法时，系统会在运行时偷偷地动态传入两个隐藏参数self和_cmd，之所以称它们为隐藏参数，是因为在源代码中没有声明和定义这两个参数。self在上面已经讲解明白了，接下来就来说说_cmd。_cmd表示当前调用方法，其实它就是一个方法选择器SEL。
     
     obj被转换成了一个指向Sark Class的指针，然后使用id转换成了objc_object类型。obj现在已经是一个Sark类型的实例对象了。当然接下来可以调用speak的方法。
     
     
     Objc中的对象到底是什么呢？
     
     实质：Objc中的对象是一个指向ClassObject地址的变量，即 id obj = &ClassObject ， 而对象的实例变量 void *ivar = &obj + offset(N)
     
     
    **/
}



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    
    //Objective-C具有相当多的动态特性，基本的，也是经常被提到和用到的有动态类型（Dynamic typing），动态绑定（Dynamic binding）和动态加载（Dynamic loading）。

    id obj = [NSString string];
    if ([obj isMemberOfClass:[NSObject class]]) {
        NSLog(@"isMemberOfClass");
    }
    
    if ([obj isKindOfClass:[NSObject class]]) {
        NSLog(@"isKindOfClass");
    }
    
    if ([obj conformsToProtocol:@protocol(NSCoding)]) {
        NSLog(@"NSCoding");
    }
    
    SEL sel = @selector(hello);
    IMP imp = [self methodForSelector:sel];
//    imp();

    
    //***************************************************
    
    
    //    获取属性列表
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *propertyName = property_getName(propertyList[i]);
        NSLog(@"property---->%@", [NSString stringWithUTF8String:propertyName]);
    }

    
    //获取方法列表
    Method *methodList = class_copyMethodList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Method method = methodList[i];
        NSLog(@"method****>%@", NSStringFromSelector(method_getName(method)));
    }
    
    
    //获取成员变量列表
    Ivar *ivarList = class_copyIvarList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Ivar myIvar = ivarList[i];
        const char *ivarName = ivar_getName(myIvar);
        NSLog(@"Ivar---->%@", [NSString stringWithUTF8String:ivarName]);
    }
    
    
    //    获取协议列表
    __unsafe_unretained Protocol **protocolList = class_copyProtocolList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Protocol *myProtocal = protocolList[i];
        const char *protocolName = protocol_getName(myProtocal);
        NSLog(@"protocol---->%@", [NSString stringWithUTF8String:protocolName]);
    }
    
    
    //************** 消息转发
    Obj *objSender = [[Obj alloc] init];
    [objSender performSelector:@selector(foo)];
 
    

    [self runtimeTest];
    
}

- (void)hello{
    NSLog(@"hello");
}

@end


@implementation Obj
{
    Obj2 *obj2;
}

- (instancetype)init{
    if ([super init]) {
        obj2 = [[Obj2 alloc] init];
    }
    return self;
}

//- (void)foo{
//    NSLog(@"如果打开注释，可以执行foo");
//}

#pragma mark 1. **动态方法解析**
//1.首先，Runtime会调用 +resolveInstanceMethod: 或者 +resolveClassMethod:，让你有机会提供一个函数实现。如果你添加了函数并返回 YES， 那运行时系统就会重新启动一次消息发送的过程
+ (BOOL)resolveInstanceMethod:(SEL)sel{
    
    if (sel == @selector(foo)) {
        class_addMethod([self class], sel, (IMP)fooMethod, "v@:");
        //        参数说明： (IMP)fooMethod 表示的是fooMethod的地址指针; "v@:" 意思是，v代表无返回值void，如果是i则代表int；@代表 id sel; : 代表 SEL _cmd; “v@:@@” 意思是，两个参数的没有返回值。
        
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

void fooMethod(id obj,SEL _cmd){
    NSLog(@"成功添加了foo");
}


#pragma mark 2. **消息转发（Message Forwarding）-- Fast forwarding**
//2.Fast forwarding,如果目标对象实现了 -forwardingTargetForSelector: ，Runtime 这时就会调用这个方法，给你把这个消息转发给其他对象的机会
- (id)forwardingTargetForSelector:(SEL)aSelector{
    if (aSelector == @selector(foo)) {
        return nil;
    }
    return [super forwardingTargetForSelector:aSelector];
}


#pragma mark 3. **消息转发（Message Forwarding）-- Normal forwarding **
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
    
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    
    if (!signature)
        signature = [obj2 methodSignatureForSelector:aSelector];
        return signature;
}


- (void)forwardInvocation:(NSInvocation *)anInvocation{
    
    SEL sel = anInvocation.selector;
    if ([obj2 respondsToSelector:sel]) {
        [anInvocation invokeWithTarget:obj2];
    }else{
        [self doesNotRecognizeSelector:sel];
    }
}


@end


@implementation Obj2

- (void)foo{
    NSLog(@"调用了Obj2 中的foo");
}

@end
