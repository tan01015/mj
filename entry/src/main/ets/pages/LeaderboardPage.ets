import { statisticsManager, PlayerStatistics } from '../utils/StatisticsManager';
import router from '@ohos.router';

@Entry
@Component
struct LeaderboardPage {
  @State leaderboard: Array<{ playerId: string; stats: PlayerStatistics }> = [];
  @State selectedTab: number = 0; // 0: 排行榜, 1: 历史记录

  aboutToAppear() {
    this.loadLeaderboard();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('←')
          .width(40)
          .height(40)
          .fontSize(20)
          .backgroundColor('transparent')
          .fontColor('#fff')
          .onClick(() => {
            try {
              router.back();
            } catch (e) {
              console.error('Router back error:', e);
            }
          })

        Text('排行榜')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(40)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })
      .backgroundColor('rgba(0,0,0,0.3)')

      // 标签页切换
      Row() {
        Text('排行榜')
          .fontSize(18)
          .fontColor(this.selectedTab === 0 ? '#FFD700' : '#ffffff80')
          .fontWeight(this.selectedTab === 0 ? FontWeight.Bold : FontWeight.Normal)
          .padding(15)
          .onClick(() => {
            this.selectedTab = 0;
          })

        Text('历史记录')
          .fontSize(18)
          .fontColor(this.selectedTab === 1 ? '#FFD700' : '#ffffff80')
          .fontWeight(this.selectedTab === 1 ? FontWeight.Bold : FontWeight.Normal)
          .padding(15)
          .onClick(() => {
            this.selectedTab = 1;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor('rgba(0,0,0,0.2)')

      // 内容区域
      if (this.selectedTab === 0) {
        this.buildLeaderboard()
      } else {
        this.buildHistory()
      }
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
          .fontSize(60)
          .margin({ bottom: 20 })

        Text('暂无数据')
          .fontSize(18)
          .fontColor('#ffffff80')

        Text('完成游戏后将显示排行榜')
          .fontSize(14)
          .fontColor('#ffffff60')
          .margin({ top: 10 })
      }
      .width('100%')
      .height('100%')
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
      .width('100%')
      .height('100%')
      .padding(15)
    }
  }

  @Builder
  buildPlayerCard(item: { playerId: string; stats: PlayerStatistics }, rank: number): void {
    Row() {
      // 排名
      Column() {
        Text(`${rank + 1}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(rank < 3 ? ['#FFD700', '#C0C0C0', '#CD7F32'][rank] : '#ffffff80')
      }
      .width(50)
      .justifyContent(FlexAlign.Center)

      // 玩家信息
      Column() {
        Text(item.playerId)
          .fontSize(18)
          .fontColor('#fff')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)

        Row() {
          Text(`胜率: ${item.stats.winRate.toFixed(1)}%`)
            .fontSize(13)
            .fontColor('#4CAF50')
          
          Text(` | `)
            .fontSize(13)
            .fontColor('#ffffff60')

          Text(`场均: ${item.stats.averageScore.toFixed(1)}`)
            .fontSize(13)
            .fontColor('#2196F3')
        }
        .margin({ top: 5 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      // 统计数据
      Column() {
        Text(`${item.stats.winCount}胜`)
          .fontSize(14)
          .fontColor('#4CAF50')
          .margin({ bottom: 5 })

        Text(`${item.stats.totalGames}场`)
          .fontSize(14)
          .fontColor('#ffffffcc')
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 10 })
    }
    .width('100%')
    .padding(15)
    .backgroundColor(rank < 3 ? 'rgba(255,215,0,0.1)' : 'rgba(255,255,255,0.05)')
    .borderRadius(10)
    .margin({ bottom: 10 })
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
          .fontSize(60)
          .margin({ bottom: 20 })

        Text('暂无历史记录')
          .fontSize(18)
          .fontColor('#ffffff80')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List() {
        ForEach(history, (record) => {
          ListItem() {
            Column() {
              Row() {
                Text(`获胜者: ${record.winner}`)
                  .fontSize(16)
                  .fontColor('#FFD700')
                  .fontWeight(FontWeight.Bold)

                Blank()

                Text(new Date(record.timestamp).toLocaleDateString())
                  .fontSize(12)
                  .fontColor('#ffffff80')
              }
              .width('100%')

              Row() {
                Text(`参与人数: ${record.players.length}`)
                  .fontSize(14)
                  .fontColor('#ffffffcc')
                
                Blank()

                Text(`最高分: ${Math.max(...Object.values(record.scores))}`)
                  .fontSize(14)
                  .fontColor('#4CAF50')
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .padding(15)
            .backgroundColor('rgba(255,255,255,0.05)')
            .borderRadius(10)
            .margin({ bottom: 10 })
          }
        }, (record) => record.gameId)
      }
      .width('100%')
      .height('100%')
      .padding(15)
    }
  }

  loadLeaderboard(): void {
    this.leaderboard = statisticsManager.getLeaderboard();
  }
}
