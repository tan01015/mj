import router from '@ohos.router';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct MainMenuPage {
  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });
  }

  build() {
    Stack() {
      // 背景装饰
      Row() {
        Column() {
          Text('🀄')
            .fontSize(120)
            .opacity(0.15)
            .rotate({ angle: -15 })
        }
        .margin({ left: 60, top: 40 })

        Blank()

        Column() {
          Text('🀅')
            .fontSize(100)
            .opacity(0.15)
            .rotate({ angle: 20 })
        }
        .margin({ right: 80, bottom: 60 })
      }
      .width('100%')
      .height('100%')

      // 主内容
      Row() {
        // 左侧Logo区域
        Column() {
          Text('🀄')
            .fontSize(90)
            .margin({ bottom: 15 })

          Text('麻将对决')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
            .letterSpacing(4)

          Text('MAHJONG BATTLE')
            .fontSize(14)
            .fontColor('#FFD700')
            .letterSpacing(8)
            .margin({ top: 8 })

          Text('支持2-4人对战')
            .fontSize(13)
            .fontColor('#ffffff80')
            .margin({ top: 30 })
        }
        .width('30%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 右侧模式选择区域
        Column() {
          Text('请选择对战模式')
            .fontSize(20)
            .fontColor('#ffffffcc')
            .margin({ bottom: 40 })
            .alignSelf(ItemAlign.Start)
            .margin({ left: 20 })

          Row({ space: 40 }) {
            this.renderModeCard(
              '🀄',
              '单人对战',
              '手动操控四家明牌',
              '适合练习和熟悉规则',
              '#4CAF50',
              () => this.enterSinglePlayer()
            )

            this.renderModeCard(
              '🌐',
              '联机对战',
              '与好友面对面竞技',
              '需要同一局域网连接',
              '#2196F3',
              () => this.enterMultiplayer()
            )
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ left: 20 })

          Blank()

          // 底部按钮
          Row() {
            Button('🏆 排行榜')
              .fontSize(16)
              .height(50)
              .width(140)
              .backgroundColor('rgba(255, 215, 0, 0.2)')
              .fontColor('#FFD700')
              .borderRadius(25)
              .onClick(() => {
                try {
                  router.pushUrl({ url: 'pages/LeaderboardPage' });
                } catch (e) {
                  console.error('Router push error:', e);
                }
              })

            Blank()

            Button('← 返回')
              .fontSize(16)
              .height(50)
              .width(120)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .fontColor('#fff')
              .borderRadius(25)
              .onClick(() => {
                try {
                  router.back();
                } catch (e) {
                  console.error('Router back error:', e);
                }
              })
          }
          .width('100%')
          .padding({ right: 40 })
        }
        .width('70%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 40, bottom: 40 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  @Builder
  renderModeCard(icon: string, title: string, desc: string, hint: string, color: string, onClick: () => void): void {
    Column() {
      Text(icon)
        .fontSize(70)
        .margin({ bottom: 15 })

      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .margin({ bottom: 8 })

      Text(desc)
        .fontSize(14)
        .fontColor('#ffffffcc')
        .textAlign(TextAlign.Center)
        .maxLines(1)

      Text(hint)
        .fontSize(12)
        .fontColor('#ffffff80')
        .margin({ top: 8 })
    }
    .width(220)
    .height(220)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255, 255, 255, 0.08)')
    .borderRadius(16)
    .border({ width: 2, color: color })
    .shadow({
      radius: 15,
      color: color + '40',
      offsetX: 0,
      offsetY: 5
    })
    .onClick(() => {
      onClick();
    })
  }

  enterSinglePlayer(): void {
    console.info('进入单人对战');
    try {
      router.pushUrl({ url: 'pages/SinglePlayerPage' });
    } catch (e) {
      console.error('Router push error:', e);
    }
  }

  enterMultiplayer(): void {
    console.info('进入局域网对战');
    try {
      router.pushUrl({ url: 'pages/LobbyPage' });
    } catch (e) {
      console.error('Router push error:', e);
    }
  }
}
