// pages/WelcomePage.ets
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { ApiService, ConfigManager, UserStore } from '../utils/HttpUtil';

// 路由参数接口
interface RouterParams {
  username: string;
  phone: string;
}

@Entry
@Component
struct WelcomePage {
  @State username: string = '';
  @State phone: string = '';
  @State currentTime: string = '';

  // 缓存UIContext
  private cachedUiContext: UIContext | null = null;

  //设置定时器检查token状态
  private timerId: number = -1;

  aboutToAppear(): void {
    //初始化 Context
    UserStore.getInstance().init(this.getUIContext());

    //立即检查一次
    this.checkTokenStatus();

    // 每隔5000毫秒自动检查一次 Token 状态，实现自动踢出
    this.timerId = setInterval(() => {
      this.checkTokenStatus();
    }, 5000);

    try {
      this.cachedUiContext = this.getUIContext();
      //每次进入页面，都将最新的 Context 注入 UserStore，这样 HttpUtil 全局拦截时，就能拿到当前页面的 Context 进行跳转
      if (this.cachedUiContext) {
        UserStore.getInstance().init(this.cachedUiContext);
      }
    } catch (err) {
      console.error('UIContext init failed', err);
    }



    // 获取路由传递的参数
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        const params = router.getParams() as RouterParams;
        if (params) {
          this.username = params.username || '用户';
          this.phone = params.phone || '';
        }
      }
    } catch (err) {
      console.error('获取路由参数失败：', err);
    }

    // 如果路由参数为空，尝试从ConfigManager获取
    if (!this.username || this.username === '用户') {
      const userInfo = ConfigManager.getUserInfo();
      if (userInfo) {
        this.username = userInfo.username || '用户';
        this.phone = userInfo.phone || '';
      }
    }



/*    // 获取当前时间
    this.updateTime();*/
    // 初始化数据
    this.initData();

    //页面加载时，主动发起一个请求来验证 Token 有效性
    // 如果 Token 失效或被踢，HttpUtil 会自动跳转回登录页
    this.checkTokenStatus();

    this.updateTime();
  }
  // 从路由参数或缓存加载数据
  private initData() {
    // 获取路由传递的参数
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        const params = router.getParams() as RouterParams;
        if (params) {
          this.username = params.username || '用户';
          this.phone = params.phone || '';
        }
      }
    } catch (err) {
      console.error('获取路由参数失败：', err);
    }
    // 如果没有路由参数，从 ConfigManager 取
    if (!this.username || this.username === '用户') {
      const userInfo = ConfigManager.getUserInfo();
      if (userInfo) {
        this.username = userInfo.username || '用户';
        this.phone = userInfo.phone || '';
      }
    }
  }
  //验证 Token 状态的方法
  private async checkTokenStatus() {
    try {
      // 调用 getUserInfo 接口，该接口在 ApiService 中定义了
      // 这里的目的不是为了数据，而是为了触发 HttpUtil 的拦截器
      await ApiService.getUserInfo();
      console.log('Token 验证通过，连接正常');
    } catch (error) {
      // 这里的 error 已经被 HttpUtil 处理过了，弹窗+跳转
      // 只需要处理非 401/409 的网络错误即可
      const err = error as BusinessError;
      if (err.code !== 401 && err.code !== 409) {
        console.error('检查登录状态失败');
      }
    }
  }
  // 更新时间
  private updateTime(): void {
    const now = new Date();
    const year = now.getFullYear();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const seconds = now.getSeconds().toString().padStart(2, '0');
    this.currentTime = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  // 手机号脱敏
  private maskPhone(phone: string): string {
    if (phone && phone.length === 11) {
      return phone.substring(0, 3) + '****' + phone.substring(7);
    }
    return phone || '未知';
  }


  // 退出登录
  private logout(): void {
    // 清除登录信息
    ConfigManager.clear();

    promptAction.openToast({ message: '已退出登录' });

    // 延迟返回登录页
    setTimeout(() => {
      this.navigateToLogin();
    }, 500);
  }

  // 页面销毁时清理定时器
  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
  }

  // 跳转到登录页
  private navigateToLogin(): void {
    try {
      if (this.cachedUiContext !== null) {
        const router = this.cachedUiContext.getRouter();
        if (router && typeof router.replaceUrl === 'function') {
          router.replaceUrl({ url: 'pages/index' });
          console.log("跳转到登录页成功");
        } else {
          throw new Error('Router.replaceUrl方法不存在或无效');
        }
      } else {
        throw new Error('UIContext为空');
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('跳转登录页失败：', error.message);

      // 兜底：尝试使用back()
      try {
        if (this.cachedUiContext !== null) {
          const router = this.cachedUiContext.getRouter();
          if (router && typeof router.back === 'function') {
            router.back();
            console.log('使用back()返回成功');
          }
        }
      } catch (err2) {
        console.error('back()也失败：', err2);
        promptAction.openToast({ message: '返回失败，请手动操作' });
      }
    }
  }

  build() {
    Column() {

      // 登陆成功
      Text('登录成功!')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 20 })

      // 欢迎回来
      Text('欢迎回来')
        .fontSize(18)
        .fontColor('#666666')
        .margin({ bottom: 10 })

      // 用户名
      Text(this.username)
        .fontSize(28)
        .fontColor('#007DFF')
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 15 })

      // 手机号（脱敏）
      Row() {
        Text('手机号: ')
          .fontSize(16)
          .fontColor('#999999')
        Text(this.maskPhone(this.phone))
          .fontSize(16)
          .fontColor('#666666')
      }
      .margin({ bottom: 10 })

      // 登录时间
      Row() {
        Text('登录时间: ')
          .fontSize(16)
          .fontColor('#999999')
        Text(this.currentTime)
          .fontSize(16)
          .fontColor('#666666')
      }
      .margin({ bottom: 40 })

      // 退出登录按钮
      Button('退出登录')
        .width('70%')
        .height(48)
        .fontSize(18)
        .fontColor('#FF4D4F')
        .backgroundColor('#FFF1F0')
        .borderRadius(24)
        .borderWidth(1)
        .borderColor('#FFCCC7')
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}