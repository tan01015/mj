import router from '@ohos.router';

@Entry
@Component
struct Index {
  aboutToAppear() {
    router.replaceUrl({ url: 'pages/SplashPage' });
  }

  build() {
    Column() {
      Text('加载中...')
        .fontSize(20)
        .fontColor('#666')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#1a1a2e')
  }
}