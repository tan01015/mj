import { networkManager, SendData } from '../utils/NetworkManager';
import { gameManager, GameState } from '../utils/GameManager';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct GamePage {
  @State gameState: GameState = gameManager.gameState;
  @State selectedTile: number | null = null;
  private unsubscribe: () => void = () => {};

  aboutToAppear() {
    this.unsubscribe = gameManager.subscribe((state: GameState) => {
      this.gameState = state;
    });
  }

  aboutToDisappear() {
    this.unsubscribe();
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text(`房间号: ${this.gameState.roomId || '123456'}`)
            .fontSize(12)
            .fontColor('#fff')
          Text(`玩法: 红中麻将`)
            .fontSize(12)
            .fontColor('#ffffff80')
          Text(`局数: 1/8`)
            .fontSize(12)
            .fontColor('#ffffff80')
        }
        .width(120)
        .padding({ left: 20 })

        Blank()

        Column({ space: 5 }) {
          Stack() {
            Circle()
              .width(35)
              .height(35)
              .fill('#ff6b6b')
            
            Text('👤')
              .fontSize(16)
          }
          
          Text('玩家')
            .fontSize(14)
            .fontColor('#fff')
            .fontWeight(FontWeight.Medium)
          Text('123456789')
            .fontSize(12)
            .fontColor('#ffffff80')
        }
        .width(100)
        .alignItems(HorizontalAlign.Center)

        Blank()

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], (i: number) => {
            Column() {
              Text('🀄')
                .fontSize(20)
            }
            .width(30)
            .height(40)
            .backgroundColor('#d4a574')
            .borderRadius(4)
            .margin(2)
          })
        }
        .width(320)

        Blank()

        Column({ space: 15 }) {
          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill('rgba(255,255,255,0.2)')
            
            Text('✓')
              .fontSize(20)
              .fontColor('#4CAF50')
          }

          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill('rgba(255,255,255,0.2)')
            
            Text('😊')
              .fontSize(18)
          }

          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill('rgba(255,255,255,0.2)')
            
            Text('🎤')
              .fontSize(18)
          }
        }
        .width(60)
        .padding({ right: 20 })
      }
      .width('100%')
      .height(70)
      .backgroundColor('#1a5e1f')

      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill('#16521a')
            .border({ width: 2, color: '#2d8a34' })
          
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(70)
              .height(70)
              .fill('#1a5e1f')
            
            Column({ space: 3 }) {
              Text('🀄')
                .fontSize(22)
                .fontColor('#FFD700')
              Text(`${this.gameState.remainingTiles || 136}`)
                .fontSize(11)
                .fontColor('#ffffff80')
            }
          }
        }

        Stack() {
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(40)
                .height(40)
                .fill('#c0392b')
              Text('北')
                .fontSize(14)
                .fontColor('#fff')
                .fontWeight(FontWeight.Bold)
            }
          }
          .position({ top: 0, left: '50%' })
          .margin({ left: -20 })

          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(40)
                .height(40)
                .fill('#3498db')
              Text('东')
                .fontSize(14)
                .fontColor('#fff')
                .fontWeight(FontWeight.Bold)
            }
          }
          .position({ top: '50%', right: 0 })
          .margin({ top: -20 })

          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(40)
                .height(40)
                .fill('#f39c12')
              Text('南')
                .fontSize(14)
                .fontColor('#fff')
                .fontWeight(FontWeight.Bold)
            }
          }
          .position({ bottom: 0, left: '50%' })
          .margin({ left: -20 })

          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(40)
                .height(40)
                .fill('#27ae60')
              Text('西')
                .fontSize(14)
                .fontColor('#fff')
                .fontWeight(FontWeight.Bold)
            }
          }
          .position({ top: '50%', left: 0 })
          .margin({ top: -20 })
        }

        Column() {
          this.renderPlayerSeat(1, 'AI-简单', '🌱', false)
        }
        .position({ top: 20, left: 40 })

        Column() {
          this.renderPlayerSeat(2, 'AI-困难', '🌳', false)
        }
        .position({ top: 20, right: 40 })

        Column() {
          this.renderPlayerSeat(3, 'AI-中等', '🌿', false)
        }
        .position({ bottom: 180, left: 40 })

        Column() {
          this.renderPlayerSeat(0, '玩家', '👤', true)
        }
        .position({ bottom: 180, right: 40 })
      }
      .width('100%')
      .flexGrow(1)
      .backgroundColor('#145019')

      Column() {
        Text('我的手牌')
          .fontSize(13)
          .fontColor('#ffffffcc')
          .margin({ bottom: 6 })
          .alignSelf(ItemAlign.Center)

        Row({ space: 2 }) {
          ForEach(this.gameState.myHand.length > 0 ? this.gameState.myHand : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], (tile: number, index: number) => {
            Column() {
              Text(tile.toString())
                .width(52)
                .height(70)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .backgroundColor(this.selectedTile === tile ? '#FFD700' : '#fff')
                .fontColor(this.selectedTile === tile ? '#1a1a1a' : '#333')
                .borderRadius(7)
                .textAlign(TextAlign.Center)
                .shadow({
                  radius: this.selectedTile === tile ? 6 : 3,
                  color: this.selectedTile === tile ? '#FFD700' : '#000',
                  offsetX: 0,
                  offsetY: 2
                })
                .onClick(() => {
                  this.selectTile(tile);
                })
            }
          }, (tile: number, index: number) => `tile-${index}`)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 15, right: 15 })

        Row() {
          Blank()
          Button('出牌')
            .width(100)
            .height(45)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.selectedTile !== null ? '#4CAF50' : '#666')
            .fontColor('#fff')
            .borderRadius(8)
            .enabled(this.selectedTile !== null)
            .onClick(() => {
              if (this.selectedTile !== null) {
                this.discardTile(this.selectedTile);
              }
            })
            .margin({ right: 15 })

          Button('退出')
            .width(70)
            .height(45)
            .fontSize(14)
            .backgroundColor('#e74c3c')
            .fontColor('#fff')
            .borderRadius(8)
            .onClick(() => {
              this.leaveGame();
            })
            .margin({ right: 20 })
        }
        .width('100%')
        .height(55)
      }
      .width('100%')
      .height(130)
      .backgroundColor('#1a5e1f')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#145019')
    .padding({ bottom: 0 })
    .margin({ bottom: 0 })
  }

  @Builder
  renderPlayerSeat(seat: number, name: string, icon: string, isActive: boolean): void {
    Column({ space: 4 }) {
      Stack() {
        Circle()
          .width(40)
          .height(40)
          .fill(isActive ? '#4CAF50' : '#3498db')
        
        Text(icon)
          .fontSize(18)
      }

      Text(name)
        .fontSize(13)
        .fontColor('#fff')
        .fontWeight(FontWeight.Medium)

      Text('手牌: 13张')
        .fontSize(11)
        .fontColor('#ffffff80')
    }
    .width(75)
    .height(80)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255,255,255,0.08)')
    .borderRadius(8)
    .border({ width: isActive ? 2 : 0, color: '#4CAF50' })
  }

  selectTile(tile: number): void {
    this.selectedTile = this.selectedTile === tile ? null : tile;
  }

  discardTile(tile: number): void {
    const actionData: SendData = {
      type: 'PLAYER_ACTION',
      action: 'DISCARD',
      tile: tile
    };
    networkManager.send('PLAYER_ACTION', actionData);
    this.selectedTile = null;
  }

  leaveGame(): void {
    networkManager.disconnect();
    gameManager.reset();
    try {
      router.back();
    } catch (e) {
      console.error('Router back error:', e);
    }
  }
}
