import { statisticsManager, PlayerStatistics } from '../utils/StatisticsManager';
import router from '@ohos.router';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct LeaderboardPage {
  @State leaderboard: Array<{ playerId: string; stats: PlayerStatistics }> = [];
  @State selectedTab: number = 0; // 0: 排行榜, 1: 历史记录

  aboutToAppear() {
    // 设置横屏全屏
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });
    this.loadLeaderboard();
  }

  build() {
    Stack() {
      // 背景装饰
      Row() {
        Text('🏆')
          .fontSize(150)
          .opacity(0.08)
          .margin({ left: 100 })
        Blank()
        Text('📊')
          .fontSize(120)
          .opacity(0.08)
          .margin({ right: 150 })
      }
      .width('100%')
      .height('100%')

      // 主内容
      Row() {
        // 左侧导航
        Column() {
          Row() {
            Button('←')
              .fontSize(22)
              .width(50)
              .height(50)
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

            Blank()

            Text('返回')
              .fontSize(16)
              .fontColor('#ffffff80')
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20 })

          Divider()
            .color('rgba(255, 255, 255, 0.15)')
            .margin({ top: 15 })

          // 标签页切换
          Column() {
            Button('🏆 排行榜')
              .width('90%')
              .height(50)
              .fontSize(16)
              .backgroundColor(this.selectedTab === 0 ? 'rgba(255, 215, 0, 0.25)' : 'rgba(255, 255, 255, 0.08)')
              .fontColor(this.selectedTab === 0 ? '#FFD700' : '#ffffff80')
              .borderRadius(25)
              .onClick(() => {
                this.selectedTab = 0;
              })

            Button('📝 历史记录')
              .width('90%')
              .height(50)
              .fontSize(16)
              .backgroundColor(this.selectedTab === 1 ? 'rgba(255, 215, 0, 0.25)' : 'rgba(255, 255, 255, 0.08)')
              .fontColor(this.selectedTab === 1 ? '#FFD700' : '#ffffff80')
              .borderRadius(25)
              .margin({ top: 10 })
              .onClick(() => {
                this.selectedTab = 1;
              })
          }
          .width('100%')
          .padding(20)
          .margin({ top: 20 })

          Blank()
        }
        .width('25%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.3)')

        // 右侧内容区域
        Column() {
          // 标题
          Row() {
            Text(this.selectedTab === 0 ? '🏆 排行榜' : '📝 历史记录')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD700')
          }
          .width('100%')
          .height(60)
          .padding({ left: 30 })
          .backgroundColor('rgba(0, 0, 0, 0.2)')

          // 内容
          if (this.selectedTab === 0) {
            this.buildLeaderboard()
          } else {
            this.buildHistory()
          }
        }
        .width('75%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a2e')
  }

  @Builder
  buildLeaderboard(): void {
    if (this.leaderboard.length === 0) {
      Column() {
        Text('📊')
          .fontSize(80)
          .margin({ bottom: 20 })

        Text('暂无数据')
          .fontSize(20)
          .fontColor('#ffffff80')

        Text('完成游戏后将显示排行榜')
          .fontSize(15)
          .fontColor('#ffffff60')
          .margin({ top: 10 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List() {
        ForEach(this.leaderboard, (item: { playerId: string; stats: PlayerStatistics }, index: number) => {
          ListItem() {
            this.buildPlayerCard(item, index)
          }
        }, (item: { playerId: string; stats: PlayerStatistics }) => item.playerId)
      }
      .width('95%')
      .layoutWeight(1)
      .padding({ top: 15, bottom: 15 })
    }
  }

  @Builder
  buildPlayerCard(item: { playerId: string; stats: PlayerStatistics }, rank: number): void {
    Row() {
      // 排名
      Column() {
        Text(`${rank + 1}`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(rank < 3 ? ['#FFD700', '#C0C0C0', '#CD7F32'][rank] : '#ffffff80')
      }
      .width(60)
      .justifyContent(FlexAlign.Center)

      // 玩家信息
      Column() {
        Text(item.playerId)
          .fontSize(20)
          .fontColor('#fff')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)

        Row() {
          Text(`胜率: ${item.stats.winRate.toFixed(1)}%`)
            .fontSize(14)
            .fontColor('#4CAF50')

          Text(` | `)
            .fontSize(14)
            .fontColor('#ffffff60')

          Text(`场均: ${item.stats.averageScore.toFixed(1)}`)
            .fontSize(14)
            .fontColor('#2196F3')
        }
        .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 15 })

      // 统计数据
      Column() {
        Text(`${item.stats.winCount}胜`)
          .fontSize(16)
          .fontColor('#4CAF50')
          .margin({ bottom: 5 })

        Text(`${item.stats.totalGames}场`)
          .fontSize(16)
          .fontColor('#ffffffcc')
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 15 })
    }
    .width('100%')
    .height(80)
    .padding({ left: 15, right: 15 })
    .backgroundColor(rank < 3 ? 'rgba(255, 215, 0, 0.1)' : 'rgba(255, 255, 255, 0.05)')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .border({
      width: rank < 3 ? 2 : 0,
      color: ['#FFD700', '#C0C0C0', '#CD7F32'][rank % 3]
    })
  }

  @Builder
  buildHistory(): void {
    const history = statisticsManager.getGameHistory(20);

    if (history.length === 0) {
      Column() {
        Text('📝')
          .fontSize(80)
          .margin({ bottom: 20 })

        Text('暂无历史记录')
          .fontSize(20)
          .fontColor('#ffffff80')
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List() {
        ForEach(history, (record) => {
          ListItem() {
            Row() {
              // 左侧信息
              Column() {
                Text(`获胜者: ${record.winner}`)
                  .fontSize(18)
                  .fontColor('#FFD700')
                  .fontWeight(FontWeight.Bold)

                Text(`参与人数: ${record.players.length}`)
                  .fontSize(14)
                  .fontColor('#ffffffcc')
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              // 右侧信息
              Column() {
                Text(new Date(record.timestamp).toLocaleDateString())
                  .fontSize(14)
                  .fontColor('#ffffff80')

                Text(`最高分: ${Math.max(...Object.values(record.scores))}`)
                  .fontSize(16)
                  .fontColor('#4CAF50')
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .height(70)
            .padding({ left: 20, right: 20 })
            .backgroundColor('rgba(255, 255, 255, 0.05)')
            .borderRadius(12)
            .margin({ bottom: 12 })
          }
        }, (record) => record.gameId)
      }
      .width('95%')
      .layoutWeight(1)
      .padding({ top: 15, bottom: 15 })
    }
  }

  loadLeaderboard(): void {
    this.leaderboard = statisticsManager.getLeaderboard();
  }
}
