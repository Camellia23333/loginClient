import { ApiService, ProductModel } from '../utils/HttpUtil';
import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct ProductListPage {
  @State productList: ProductModel[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    try {
      const res = await ApiService.getProductList();
      if (res.code === 200 && res.data) {
        this.productList = res.data;
      } else {
        promptAction.showToast({ message: res.message || '加载失败' });
      }
    } catch (err) {
      promptAction.showToast({ message: '网络异常' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 1. 顶部标题栏
      Row() {
        Text('< 返回')
          .fontSize(16)
          .padding(10)
          .onClick(() => router.back())
        Text('商品列表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 20 })
      }
      .width('100%')
      .height(50)
      .backgroundColor('#FFF')
      .border({ width: { bottom: 1 }, color: '#F1F1F1' })

      // 2. 列表区域
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('正在加载好货...').fontSize(14).fontColor('#999').margin({ top: 10 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.productList, (item: ProductModel) => {
            ListItem() {
              this.ProductCard(item)
            }
            .onClick(() => {
              // === 核心跳转逻辑 ===
              // 跳转到详情页，并传递参数 params
              router.pushUrl({
                url: 'pages/ProductPage',
                params: {
                  id: item.id // 把商品ID传过去
                }
              })
            })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding(10)
        .backgroundColor('#F5F5F5')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 抽取每一个商品卡片的样式，让代码更整洁
  @Builder ProductCard(item: ProductModel) {
    Row() {
      // 左侧：模拟图片
      Column()
        .width(80)
        .height(80)
        .backgroundColor('#EEE')
        .borderRadius(8)
        .margin({ right: 10 })

      // 右侧：信息
      Column({ space: 5 }) {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`库存: ${item.availableStock}`)
          .fontSize(12)
          .fontColor('#999')

        Blank() // 撑开空间

        Text(`￥${item.price}`)
          .fontSize(18)
          .fontColor('#FF0033')
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .height(80)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FFF')
    .borderRadius(10)
  }
}