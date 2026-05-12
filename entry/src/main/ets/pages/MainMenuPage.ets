import router from '@ohos.router';

@Entry
@Component
struct MainMenuPage {
  build() {
    Column() {
      Row() {
        Column() {
          Text('🀄')
            .fontSize(70)
            .margin({ bottom: 10 })

          Text('麻将对决')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fff')
            .letterSpacing(3)

          Text('MAHJONG BATTLE')
            .fontSize(12)
            .fontColor('#FFD700')
            .letterSpacing(6)
            .margin({ top: 5 })
        }
        .width('30%')
        .padding({ left: 30 })

        Column() {
          Text('请选择对战模式')
            .fontSize(18)
            .fontColor('#ffffffcc')
            .margin({ bottom: 30 })
            .alignSelf(ItemAlign.Center)

          Row({ space: 25 }) {
            this.renderModeCard(
              '🤖',
              '单人对战',
              '与AI对手切磋技艺',
              '#4CAF50',
              () => this.enterSinglePlayer()
            )

            this.renderModeCard(
              '🌐',
              '联机对战',
              '与好友面对面竞技',
              '#2196F3',
              () => this.enterMultiplayer()
            )
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('70%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 20 })

      Row() {
        Text('支持2-4人对战')
          .fontSize(14)
          .fontColor('#ffffff80')
          .padding({ left: 30 })

        Blank()

        Button('🏆')
          .fontSize(20)
          .width(45)
          .height(45)
          .backgroundColor('rgba(255,215,0,0.2)')
          .fontColor('#FFD700')
          .margin({ right: 10 })
          .onClick(() => {
            try {
              router.pushUrl({ url: 'pages/LeaderboardPage' });
            } catch (e) {
              console.error('Router push error:', e);
            }
          })

        Button('←')
          .fontSize(24)
          .width(45)
          .height(45)
          .backgroundColor('rgba(255,255,255,0.2)')
          .fontColor('#fff')
          .padding({ right: 30 })
          .onClick(() => {
            try {
              router.back();
            } catch (e) {
              console.error('Router back error:', e);
            }
          })
      }
      .width('100%')
      .height(60)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  @Builder
  renderModeCard(icon: string, title: string, desc: string, color: string, onClick: () => void): void {
    Column() {
      Text(icon)
        .fontSize(60)
        .margin({ bottom: 10 })

      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .margin({ bottom: 5 })

      Text(desc)
        .fontSize(12)
        .fontColor('#ffffffcc')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .width(180)
    .height(180)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255,255,255,0.1)')
    .borderRadius(12)
    .border({ width: 2, color: color })
    .onClick(() => {
      onClick();
    })
  }

  enterSinglePlayer(): void {
    console.info('进入单人对战');
    try {
      router.pushUrl({ url: 'pages/GameRoomPage', params: { mode: 'single' } });
    } catch (e) {
      console.error('Router push error:', e);
    }
  }

  enterMultiplayer(): void {
    console.info('进入局域网对战');
    try {
      router.pushUrl({ url: 'pages/LobbyPage', params: { mode: 'multiplayer' } });
    } catch (e) {
      console.error('Router push error:', e);
    }
  }
}
