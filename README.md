我们都知道Objective-C 是一门动态语言，这就意味着它是一类在运行时可以改变其结构的语言，你可以按需要把消息重定向给合适的对象，甚至可以交换方法的实现。我们知道方法调用的本质就是对象发送消息，比如：`[object message]` 实际上被编译器转化成了：`objc_msgSend(object, selector)` 



####一. 动态特性

首先我们来了解一下动态特性可以大致分为动态类型（Dynamic typing），动态绑定（Dynamic binding）和动态加载（Dynamic loading）。

1. **动态类型：**

即是运行时才决定对象的类型，比如我们常用的id类型。这里需要说到几个方法：

`-isMemberOfClass:` 是 `NSObject` 的方法，用以确定某个 `NSObject` 对象是否是某个类的成员。

 `-isKindOfClass:` 可以用以确定某个对象是否是某个类或其子类的成员。

`respondsToSelector:` 检查对象能否响应指定的消息。

`conformsToProtocol:` 检查对象是否实现了指定协议类的方法。

`methodForSelector:` 返回指定方法的函数指针。


![动态类型.png](http://upload-images.jianshu.io/upload_images/3261360-3964f295afa23d98.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

2. **动态绑定**

> 基于动态类型，在某个实例对象被确定后，其类型便被确定了。该对象对应的属性和响应的消息也被完全确定，这就是动态绑定。传统的函数一般在编译时就已经把参数信息和函数实现打包到编译后的源码中了，而在OC中使用的是消息机制。调用一个实例方法，其实是向该实例的指针发送消息，实例在收到消息之后，会从自身的实现中去寻找响应这条消息的方法。而动态绑定所做的，就是在实例所属类确定后，将某些属性和相应的方法绑定到实例上。



3. **动态加载**

根据需求加载所需要的资源，比如不同设备加载不同尺寸图片。



#### 二. 具体结构 

```objective-c
//objc/runtime.h
struct objc_class {
    Class isa  OBJC_ISA_AVAILABILITY;	//isa指针

#if !__OBJC2__
    Class super_class                                        OBJC2_UNAVAILABLE;//父类指针
    const char *name                                         OBJC2_UNAVAILABLE;//类名
    long version                                             OBJC2_UNAVAILABLE;//类的版本号
    long info                                                OBJC2_UNAVAILABLE;//类的版本信息
    long instance_size                                       OBJC2_UNAVAILABLE;//实例大小
    struct objc_ivar_list *ivars                             OBJC2_UNAVAILABLE;//成员变量列表指针
    struct objc_method_list **methodLists                    OBJC2_UNAVAILABLE;//指向objc_method_list指针的指针
    struct objc_cache *cache                                 OBJC2_UNAVAILABLE;//方法缓存
    struct objc_protocol_list *protocols                     OBJC2_UNAVAILABLE;//协议链表
#endif

} OBJC2_UNAVAILABLE;
```

```objective-c
//objc/objc.h

// Class其实是一个指向objc_class结构体的指针
typedef struct objc_class *Class;

struct objc_object {
    Class isa  OBJC_ISA_AVAILABILITY;	//isa指针
};
//指向一个类实例的指针
typedef struct objc_object *id;
```



这么看来，类和对象都是一样的结构，内部都包含一个`isa`对象，那么类本身也是一个对象。

为了处理类和对象的关系，runtime 引入了元类 (Meta Class) ，类对象所属的类型就叫做元类，它用来表述类对象本身所具备的元数据。类方法就定义于此，因为这些方法可以理解成类对象的实例方法。每个类仅有一个类对象，而每个类对象仅有一个与之相关的元类。当对象的实例方法调用时，通过对象的 isa 在类中获取方法的实现。类对象的类方法调用时，通过类的 isa 在元类中获取方法的实现。

当你发出一个类似`[NSObject alloc]`的消息时，你事实上是把这个消息发给了一个类对象 (Class Object) ，这个类对象必须是一个元类的实例，而这个元类同时也是一个根元类 (root meta class) 的实例。所有的元类最终都指向根元类为其超类。所有的元类的方法列表都有能够响应消息的类方法。所以当 `[NSObject alloc]` 这条消息发给类对象的时候，`objc_msgSend()`会去它的元类里面去查找能够响应消息的方法，如果找到了，然后对这个类对象执行方法调用。

![class-diagram.jpg](http://upload-images.jianshu.io/upload_images/3261360-e941d33bed420fc7.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


其他关键字：

**1. SEL**

SEL又叫选择器，是表示一个方法的selector的指针，其定义如下：

```
typedef struct objc_selector *SEL；
```

方法的selector用于表示运行时方法的名字。Objective-C在编译时，会依据每一个方法的名字、参数序列，生成一个唯一的整型标识(Int类型的地址)，这个标识就是SEL。

两个类之间，只要方法名相同，那么方法的SEL就是一样的，每一个方法都对应着一个SEL。所以在Objective-C同一个类(及类的继承体系)中，不能存在2个同名的方法，即使参数类型不同也不行
如在某一个类中定义以下两个方法会报错

```
- (void)setWidth:(int)width;
- (void)setWidth:(double)width;
```

当然，不同的类可以拥有相同的selector，这个没有问题。不同类的实例对象执行相同的selector时，会在各自的方法列表中去根据selector寻找自己对应的IMP。

工程中的所有的SEL组成一个Set集合，如果我们想到这个方法集合中查找某个方法时，只需要去找到这个方法对应的SEL就行了，SEL实际上就是根据方法名hash化了的一个字符串，而对于字符串的比较仅仅需要比较他们的地址就可以了，可以说速度上无语伦比！

本质上，SEL只是一个指向方法的指针（准确的说，只是一个根据方法名hash化了的KEY值，能唯一代表一个方法），它的存在只是为了加快方法的查询速度。
通过下面三种方法可以获取SEL:
a、sel_registerName函数
b、Objective-C编译器提供的@selector()
c、NSSelectorFromString()方法



**2. Method**

Method用于表示类定义中的方法：

```objective-c
typedef struct objc_method *Method
struct objc_method{
    SEL method_name      OBJC2_UNAVAILABLE; // 方法名
    char *method_types   OBJC2_UNAVAILABLE;
    IMP method_imp       OBJC2_UNAVAILABLE; // 方法实现
}
```

我们可以看到该结构体中包含一个SEL和IMP，实际上相当于在SEL和IMP之间作了一个映射。有了SEL，我们便可以找到对应的IMP，从而调用方法的实现代码。



**3. IMP**

IMP实际上是一个函数指针，指向方法实现的地址。

```objective-c
id (*IMP)(id, SEL,...)
```

第一个参数：是指向self的指针(如果是实例方法，则是类实例的内存地址；如果是类方法，则是指向元类的指针)
第二个参数：是方法选择器(selector)
接下来的参数：方法的参数列表。



**4. Ivar**

`Ivar`是一种代表类中实例变量的类型。

```objective-c
typedef struct objc_ivar *Ivar;

struct objc_ivar {
    char *ivar_name                                          OBJC2_UNAVAILABLE;
    char *ivar_type                                          OBJC2_UNAVAILABLE;
    int ivar_offset                                          OBJC2_UNAVAILABLE;
#ifdef __LP64__
    int space                                                OBJC2_UNAVAILABLE;
#endif
}                                                            OBJC2_UNAVAILABLE;
```

可以根据实例查找其在类中的名字，也就是“反射”：

```objective-c
-(NSString *)nameWithInstance:(id)instance {
    unsigned int numIvars = 0;
    NSString *key=nil;
    Ivar * ivars = class_copyIvarList([self class], &numIvars);
    for(int i = 0; i < numIvars; i++) {
        Ivar thisIvar = ivars[i];
        const char *type = ivar_getTypeEncoding(thisIvar);
        NSString *stringType =  [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
        if (![stringType hasPrefix:@"@"]) {
            continue;
        }
        if ((object_getIvar(self, thisIvar) == instance)) {//此处若 crash 不要慌！
            key = [NSString stringWithUTF8String:ivar_getName(thisIvar)];
            break;
        }
    }
    free(ivars);
    return key;
}
```

`class_copyIvarList` 函数获取的不仅有实例变量，还有属性。但会在原本的属性名前加上一个下划线。

 `class_copyPropertyList` 函数只能获取类的属性。



**5. Cache**

`Cache`为方法调用的性能进行优化，通俗地讲，每当实例对象接收到一个消息时，它不会直接在`isa`指向的类的方法列表中遍历查找能够响应消息的方法，因为这样效率太低了，而是优先在`Cache`中查找。

```objective-c
typedef struct objc_cache *Cache                             OBJC2_UNAVAILABLE;

struct objc_cache {
    unsigned int mask /* total = mask + 1 */                 OBJC2_UNAVAILABLE;
    unsigned int occupied                                    OBJC2_UNAVAILABLE;
    Method buckets[1]                                        OBJC2_UNAVAILABLE;
};
```



**6. _cmd**

_cmd在Objective-C的方法中表示当前方法的selector，正如同self表示当前方法调用的对象实例。





#### 三. 调用流程

**1. 消息传递**

消息直到运行时才绑定到方法实现上。编译器会将消息表达式[receiver message]转化为一个消息函数的调用，即objc_msgSend。这个函数将消息接收者和方法名作为其基础参数，如以下所示

```objective-c
objc_msgSend(receiver, selector)
```

如果消息中还有其它参数，则该方法的形式如下所示：

```objective-c
objc_msgSend(receiver, selector, arg1, arg2,...)
```

另方法列表`objc_method_list` 本质上是一个装载 `objc_method` 元素的可变长度的数组。一个 `objc_method` 结构体中包含函数名，也就是SEL，表示函数类型的字符串 (见 [Type Encoding](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html)) ，以及函数的实现IMP。

比如：调用`[obj foo];`

1. 首先是转换成`objc_msgSend(obj, foo)`,通过对象的isa指针获取到类的结构体，然后在方法分发表里面查找方法的selector 。
2. 先去cache中找foo，找到则实现IMP；未找到则在 class 的 method list 找 foo 。
3. 如果 class 中没到 foo，继续往它的 superclass 中找 ，即objc_msgSend结构体中的指向父类的指针找到其父类，并在父类的分发表里面查找方法的selector。
4. 依次沿着类的继承体系到NSObject，一旦找到 foo 这个函数，就去执行它的实现IMP 。并把 foo 的 `method_name` 作为 key ，`method_imp` 作为 value 存进cache
5. 如果都未找到，则会走消息转发流程



**2. 消息转发**

我们知道，当对象发送一个消息而没有实现该方法时，编译器会报如下错误：

`unrecognized selector send to instance XXX`

*Tip:*  正确的做法是当我们不确定一个对象是否能接收某个消息时，应该先判断是否能响应该方法：

```objective-c
if([self respondsToSelector:@selector(method)]){
      [self performSelector:@selector(method)];
}
```



当一个对象无法接收某个消息时，就会启动 `消息转发(message forwarding)” `机制。

如下图：

![iOS消息转发流程.png](http://upload-images.jianshu.io/upload_images/3261360-c2b77789886643ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以看到，当一个函数的实现找不到时，OC提供了三种补救的方式:

1. 调用 `resolveInstanceMethod` 或是 `resolveClassMethod` 尝试去 resolve 这个消息。

2. 如果 resolve 方法返回 NO，则调用 `forwardingTargetForSelector` 允许你把这个消息转发给另一个对象。

3. 如果没有新的目标对象返回，则调用 `methodSignatureForSelector` 和 `forwardInvocation` 灵活的将目标函数以其他形式执行。

4. 如果都不中，那就GG了，Runtime会调用 `doesNotRecognizeSelector:` 抛出异常。

   ​



*下面我们看一个具体实例是如何进行补救的：*

1.  **动态方法解析，如果在自己定义的Obj类中，没有实现foo方法，我们可以实现 `resolveInstanceMethod`方法，使用 `class_addMethod`添加一个函数实现，并返回YES，就能够成功进行补救。**

   ```objective-c
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
   ```

![resolveInstanceMethod@2x.png](http://upload-images.jianshu.io/upload_images/3261360-39877e774adfd68e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


2.  如果 ` resolveInstanceMethod ` 方法返回 NO ，并且没有调用 `class_addMethod` 添加实现方法；那么运行时就会移到下一步：**消息转发（Message Forwarding）**：如果目标对象实现了 `-forwardingTargetForSelector:` ，Runtime 这时就会调用这个方法，给你把这个消息转发给其他对象的机会。此处可以叫做Fast forwarding，因为这一步不会创建任何新的对象，所以相比Normal forwarding 会快一些，注意：此处调用的是其他对象的实例方法，所以也必须实例化该对象。


![forwardingTargetForSelector@2x.png](http://upload-images.jianshu.io/upload_images/3261360-487d0f02a1c3306c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

3.  如果 `forwardingTargetForSelector` 返回了nil或self, 就会继续 **Normal Fowarding** ，这是最后一次挽救机会了。相比上一步的fast forwarding，这里会创建一个 NSInvocation 对象。**首先它会发送` -methodSignatureForSelector: `消息获得函数的参数和返回值类型。如果该方法返回 nil ，Runtime 则会发出` -doesNotRecognizeSelector: `消息，程序这时也就挂掉了；如果返回了一个函数签名，Runtime 就会创建一个 NSInvocation 对象并发送 `-forwardInvocation:` 消息给目标对象。**

    **NSInvocation 实际上就是对一个消息的描述，包括selector 以及参数等信息。所以你可以在 `-forwardInvocation:` 里修改传进来的 NSInvocation 对象，然后发送 -invokeWithTarget: 消息给它，传进去一个新的目标。**

    **所以我们需要重写这两个方法：`methodSignatureForSelector:`和`forwardInvocation:`。**

![forwardInvocation.png](http://upload-images.jianshu.io/upload_images/3261360-35bcef2eec9c847e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

至此，Runtime的调用流程就结束了。
    ​

####四. Method Swizzling

我们知道，每个类都有一个方法列表，存放着selector的名字和方法实现的映射关系。IMP类似于函数指针，指向具体的Method实现。每一个SEL与一个IMP一一对应，正常情况下通过SEL可以查找到对应消息的IMP实现。*而Method Swizzling就可以将对应的关系解开并映射到我们自定义的函数IMP上，* KVO其实就是Apple使用了一个中间类，并进行了Swizzling。Method Swizzling的好处就在于：**不需要改动对应类的源代码，就可以更改某个方法的实现。**


![1370993-99e53531835c3451.png](http://upload-images.jianshu.io/upload_images/3261360-89f64c3696731ea9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

比如，我们经常可以在第三方框架中看到如下代码,就是一段Method Swizzling：

```objective-c
//在整个文件被加载到运行时，在 main 函数调用之前被 ObjC 运行时调用的钩子方法
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(XXX_viewWillAppear:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
          //主类本身没有实现需要替换的方法，而是继承了父类的实现，即 class_addMethod 方法返回 YES 。这时使用 class_getInstanceMethod 函数获取到的 originalSelector 指向的就是父类的方法，我们再通过执行 class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod)); 将父类的实现替换到我们自定义的 XXX_viewWillAppear 方法中。这样就达到了在 XXX_viewWillAppear 方法的实现中调用父类实现的目的。
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
          //主类本身有实现需要替换的方法，也就是 class_addMethod 方法返回 NO 。这种情况的处理比较简单，直接交换两个方法的实现就可以了
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)XXX_viewWillAppear:(BOOL)animated
{
    // Method Swizzling之后, 调用XXX_viewWillAppear:实际执行的代码已经是原来viewWillAppear中的代码了
    [self XXX_viewWillAppear:animated];
  	// 添加某些操作
}
```




参考文献：

- [Runtime Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008048)

- [深入Objective-C的动态特性](https://onevcat.com/2012/04/objective-c-runtime/)

- [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/)

  
