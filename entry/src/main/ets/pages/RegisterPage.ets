import { promptAction, router } from '@kit.ArkUI';
import { ApiService } from '../utils/HttpUtil';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct RegisterPage {
  @State phone: string = '';
  @State code: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';

  //新增：密码错误提示文字
  @State pwdError: string = '';

  // 倒计时相关状态
  @State countdown: number = 0;
  private timer: number = -1;

  @State isLoading: boolean = false;

  // 页面销毁时清理定时器，防止内存泄漏
  aboutToDisappear() {
    if (this.timer !== -1) {
      clearInterval(this.timer);
    }
  }

  /**
   * 发送验证码逻辑
   */
  private async sendVerifyCode() {
    if (this.phone.length !== 11) {
      promptAction.showToast({ message: '请输入正确的11位手机号' });
      return;
    }

    try {
      const res = await ApiService.sendCode(this.phone);
      if (res.code === 200) {
        promptAction.showToast({ message: '验证码已发送，请留意控制台或短信' });
        this.startCountdown();
      } else {
        promptAction.showToast({ message: res.message || '发送失败' });
      }
    } catch (err) {
      const error = err as BusinessError;
      promptAction.showToast({ message: '网络请求失败: ' + error.message });
    }
  }

  /**
   * 开启60秒倒计时
   */
  private startCountdown() {
    this.countdown = 60;
    this.timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(this.timer);
        this.timer = -1;
      }
    }, 1000);
  }

  /**
   * 密码强度校验 (6-13位，必须包含大小写字母、数字、特殊符号)
   */
  private validatePassword(pwd: string): boolean {
    //非空校验
    if (pwd.trim() === '') {
      this.pwdError = '请输入密码';
      return false;
    }

    //长度校验
    if (pwd.length < 6 || pwd.length > 13) {
      this.pwdError = '密码长度需为6-13位';
      return false;
    }

    //字符类型校验
    const hasNumber = /\d/.test(pwd);
    const hasLetter = /[a-zA-Z]/.test(pwd); // 只要包含字母即可，不分大小写
    const hasSymbol = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`]/.test(pwd);

    //具体错误提示
    if (!hasNumber) {
      this.pwdError = '密码必须包含数字';
      return false;
    }
    if (!hasLetter) {
      this.pwdError = '密码必须包含字母';
      return false;
    }
    if (!hasSymbol) {
      this.pwdError = '密码必须包含标点符号';
      return false;
    }

    //校验通过
    this.pwdError = '';
    return true;
  }

  /**
   * 提交注册逻辑
   */
  private async handleRegister() {
    //基础校验
    if (this.phone.length !== 11) return promptAction.showToast({ message: '请输入手机号' });
    if (this.code.length !== 4) return promptAction.showToast({ message: '请输入4位验证码' });
    //调用校验方法，如果校验不通过，validatePassword 会自动设置错误提示并返回 false
    if (!this.validatePassword(this.password)) {
      return; // 直接阻断，错误提示已经显示在 UI 上了
    }
    if (this.password !== this.confirmPassword) {
      return promptAction.showToast({ message: '两次输入的密码不一致' });
    }

    this.isLoading = true;

    try {
      //调用注册接口
      const res = await ApiService.register(this.phone, this.code, this.password);

      if (res.code === 200) {
        promptAction.showToast({ message: '注册成功！请登录' });
        // 延迟跳转，提升体验
        setTimeout(() => {
          router.back(); // 返回登录页
        }, 1000);
      } else {
        promptAction.showToast({ message: res.message || '注册失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '注册异常，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('新用户注册')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)

      // 表单区域
      Column({ space: 20 }) {

        // 手机号输入框
        TextInput({ placeholder: '请输入手机号', text: this.phone })
          .type(InputType.PhoneNumber)
          .maxLength(11)
          .onChange((val) => this.phone = val)
          .height(50)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')

        // 验证码输入框 + 按钮
        Row({ space: 10 }) {
          TextInput({ placeholder: '验证码', text: this.code })
            .type(InputType.Number)
            .maxLength(4)
            .layoutWeight(1) // 占据剩余空间
            .onChange((val) => this.code = val)
            .height(50)
            .borderRadius(8)
            .backgroundColor('#F5F5F5')

          Button(this.countdown > 0 ? `${this.countdown}s后重试` : '获取验证码')
            .enabled(this.countdown === 0 && this.phone.length === 11)
            .fontSize(14)
            .height(50)
            .backgroundColor(this.countdown > 0 ? '#CCCCCC' : '#007DFF')
            .onClick(() => this.sendVerifyCode())
        }
        .width('100%')

        //密码输入框
        TextInput({ placeholder: '设置密码', text: this.password })
          .type(InputType.Password)
          .onChange((val) => this.password = val)
          .height(50)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')
        if (this.pwdError) {
          Text(this.pwdError)
            .fontSize(12)
            .fontColor('#ff4d4f')
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ bottom: 8, left: 2 })
        }

        //确认密码输入框
        TextInput({ placeholder: '确认密码', text: this.confirmPassword })
          .type(InputType.Password)
          .onChange((val) => this.confirmPassword = val)
          .height(50)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')

        // 注册按钮
        Button(this.isLoading ? '注册中...' : '立即注册')
          .width('100%')
          .height(50)
          .fontSize(18)
          .margin({ top: 20 })
          .enabled(!this.isLoading)
          .onClick(() => this.handleRegister())

      }
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .padding({ top: 10 }) // 避开状态栏
  }
}