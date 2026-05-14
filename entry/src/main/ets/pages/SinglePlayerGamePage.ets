import { networkManager, MessageData } from '../utils/NetworkManager';
import { gameManager, GameManagerState, GamePlayer } from '../utils/GameManager';
import { MahjongRules } from '../engine/MahjongRules';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

// 手牌排序函数：相同牌放在一起
function sortHandTiles(hand: number[]): number[] {
  // 统计每种牌的数量
  const tileCounts = new Map<number, number>();
  hand.forEach((tile: number) => {
    tileCounts.set(tile, (tileCounts.get(tile) || 0) + 1);
  });
  
  // 按牌值排序
  const sortedTiles = [...hand].sort((a: number, b: number) => a - b);
  return sortedTiles;
}

interface DialogResult {
  index: number;
}

@Entry
@Component
struct SinglePlayerGamePage {
  @State gameState: GameManagerState = gameManager.gameState;
  @State selectedTileIndex: number = -1;
  @State waitingForReaction: boolean = false;
  @State availableReactions: Map<number, string[]> = new Map();
  @State discardedTile: number = 0;
  @State discardedBy: number = -1;
  @State showGameOver: boolean = false;
  @State gameOverWinner: string = '';
  @State gameOverScores: Record<number, number> = {};
  @State selfDrawWinAvailable: boolean = false;
  @State selfDrawKongAvailable: boolean = false;
  @State sortedHandVersion: number = 0; // 用于触发手牌重新排序动画
  private unsubscribe: () => void = () => {};

  aboutToAppear() {
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarEnable([]);
      win.setPreferredOrientation(window.Orientation.LANDSCAPE);
    }).catch((e: Error) => {
      console.error('set landscape fullscreen error:', JSON.stringify(e));
    });

    this.unsubscribe = gameManager.subscribe((state: GameManagerState) => {
      this.gameState = state;
    });

    this.setupNetworkListeners();
    MahjongRules.initialize();
  }

  aboutToDisappear() {
    this.unsubscribe();
    networkManager.clearHandlers();
  }

  // ==================== @Builder 方法区 ====================

  @Builder
  buildInfoBar(): void {
    Row() {
      Button('←')
        .fontSize(14)
        .width(36)
        .height(36)
        .backgroundColor('rgba(255,255,255,0.15)')
        .fontColor('#fff')
        .borderRadius(18)
        .onClick(() => {
          this.confirmLeave();
        })

      Blank()

      Row({ space: 20 }) {
        Text(`第${this.gameState.round}局`)
          .fontSize(14)
          .fontColor('#FFD700')
          .fontWeight(FontWeight.Bold)

        Text(`剩${this.gameState.remainingTiles}张`)
          .fontSize(12)
          .fontColor('#ffffffaa')

        Text(this.getCurrentTurnText())
          .fontSize(13)
          .fontColor('#7CFC00')
          .fontWeight(FontWeight.Medium)
      }

      Blank()

      if (this.waitingForReaction) {
        Text('请选择操作')
          .fontSize(11)
          .fontColor('#FF9800')
          .fontWeight(FontWeight.Bold)
      } else {
        Text('').width(36)
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 12 })
    .backgroundColor('rgba(0,0,0,0.35)')
  }

  @Builder
  buildTopPlayer(): void {
    Column({ space: 2 }) {
      Row({ space: 8 }) {
        Text(gameManager.getPlayerName(2))
          .fontSize(12)
          .fontColor(this.gameState.currentPlayer === 2 ? '#FFD700' : '#ffffffcc')
          .fontWeight(this.gameState.currentPlayer === 2 ? FontWeight.Bold : FontWeight.Normal)

        Text(`${this.getSeatHandArray(2).length}张`)
          .fontSize(10)
          .fontColor('#ffffff80')
      }
      .width('100%')
      .height(14)
      .justifyContent(FlexAlign.Center)

      Row() {
        ForEach(this.getSeatHandArray(2), (tile: number, index: number) => {
          Stack() {
            this.buildHiddenTile()
          }
          .margin({ left: index > 0 ? -16 : 0 })
          .zIndex(index)
        }, (tile: number, index: number) => `top_hand_${index}`)
      }
      .height(26)
      .justifyContent(FlexAlign.Center)

      if (this.getSeatMeldsArray(2).length > 0) {
        Row({ space: 4 }) {
          ForEach(this.getSeatMeldsArray(2), (meld: number[]) => {
            Row({ space: 1 }) {
              ForEach(meld, (tile: number, idx: number) => {
                this.buildMiniTile(tile)
              }, (tile: number, idx: number) => `top_meld_${tile}_${idx}`)
            }
          }, (meld: number[]) => `top_meld_${meld[0]}`)
        }
        .height(28)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height(72)
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  @Builder
  buildLeftPlayer(): void {
    Row({ space: 4 }) {
      Column({ space: 2 }) {
        Text(gameManager.getPlayerName(1))
          .fontSize(11)
          .fontColor(this.gameState.currentPlayer === 1 ? '#FFD700' : '#ffffffaa')
          .fontWeight(this.gameState.currentPlayer === 1 ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)

        Text(`${this.getSeatHandArray(1).length}张`)
          .fontSize(9)
          .fontColor('#ffffff80')
      }
      .width(36)
      .justifyContent(FlexAlign.Center)

      Column() {
        ForEach(this.getSeatHandArray(1), (tile: number, index: number) => {
          Stack() {
            this.buildHiddenTile()
          }
          .margin({ top: index > 0 ? -20 : 0 })
          .zIndex(index)
        }, (tile: number, index: number) => `left_hand_${index}`)
      }
      .width(22)
      .justifyContent(FlexAlign.Center)

      if (this.getSeatMeldsArray(1).length > 0) {
        Column({ space: 4 }) {
          ForEach(this.getSeatMeldsArray(1), (meld: number[]) => {
            Row({ space: 1 }) {
              ForEach(meld, (tile: number, idx: number) => {
                this.buildMiniTile(tile)
              }, (tile: number, idx: number) => `left_meld_${tile}_${idx}`)
            }
          }, (meld: number[]) => `left_meld_${meld[0]}`)
        }
        .width(44)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width(80)
    .height('100%')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  buildRightPlayer(): void {
    Row({ space: 4 }) {
      if (this.getSeatMeldsArray(3).length > 0) {
        Column({ space: 4 }) {
          ForEach(this.getSeatMeldsArray(3), (meld: number[]) => {
            Row({ space: 1 }) {
              ForEach(meld, (tile: number, idx: number) => {
                this.buildMiniTile(tile)
              }, (tile: number, idx: number) => `right_meld_${tile}_${idx}`)
            }
          }, (meld: number[]) => `right_meld_${meld[0]}`)
        }
        .width(44)
        .justifyContent(FlexAlign.Center)
      }

      Column() {
        ForEach(this.getSeatHandArray(3), (tile: number, index: number) => {
          Stack() {
            this.buildHiddenTile()
          }
          .margin({ top: index > 0 ? -20 : 0 })
          .zIndex(index)
        }, (tile: number, index: number) => `right_hand_${index}`)
      }
      .width(22)
      .justifyContent(FlexAlign.Center)

      Column({ space: 2 }) {
        Text(gameManager.getPlayerName(3))
          .fontSize(11)
          .fontColor(this.gameState.currentPlayer === 3 ? '#FFD700' : '#ffffffaa')
          .fontWeight(this.gameState.currentPlayer === 3 ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)

        Text(`${this.getSeatHandArray(3).length}张`)
          .fontSize(9)
          .fontColor('#ffffff80')
      }
      .width(36)
      .justifyContent(FlexAlign.Center)
    }
    .width(80)
    .height('100%')
    .padding({ left: 4, right: 4 })
    .direction(Direction.Rtl)
  }

  @Builder
  buildCenterArea(): void {
    Column({ space: 2 }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.getSeatDiscardedArray(2), (tile: number, index: number) => {
          this.buildMiniTile(tile)
        }, (tile: number, index: number) => `dc_2_${tile}_${index}`)
      }
      .width('100%')
      .height('22%')
      .padding(2)

      Row({ space: 2 }) {
        Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Column, justifyContent: FlexAlign.Center }) {
          ForEach(this.getSeatDiscardedArray(1), (tile: number, index: number) => {
            this.buildMiniTile(tile)
          }, (tile: number, index: number) => `dc_1_${tile}_${index}`)
        }
        .width('18%')
        .height('100%')
        .padding(2)

        Stack() {
          Column({ space: 4 }) {
            Text('🀅')
              .fontSize(24)
              .fontColor('#ffffff12')

            Text(`${this.gameState.remainingTiles}`)
              .fontSize(16)
              .fontColor('#ffffff35')
              .fontWeight(FontWeight.Bold)
          }
        }
        .layoutWeight(1)
        .height('100%')

        Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Column, justifyContent: FlexAlign.Center }) {
          ForEach(this.getSeatDiscardedArray(3), (tile: number, index: number) => {
            this.buildMiniTile(tile)
          }, (tile: number, index: number) => `dc_3_${tile}_${index}`)
        }
        .width('18%')
        .height('100%')
        .padding(2)
      }
      .layoutWeight(1)
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.getSeatDiscardedArray(0), (tile: number, index: number) => {
          this.buildMiniTile(tile)
        }, (tile: number, index: number) => `dc_0_${tile}_${index}`)
      }
      .width('100%')
      .height('22%')
      .padding(2)
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor('rgba(0,0,0,0.15)')
    .borderRadius(8)
    .border({ width: 1, color: '#0a4a24' })
  }

  @Builder
  buildBottomPlayer(): void {
    Column({ space: 4 }) {
      this.buildActionButtons()

      if (this.getSeatMeldsArray(0).length > 0) {
        Row({ space: 6 }) {
          ForEach(this.getSeatMeldsArray(0), (meld: number[]) => {
            Row({ space: 1 }) {
              ForEach(meld, (tile: number, idx: number) => {
                this.buildMiniTile(tile)
              }, (tile: number, idx: number) => `my_meld_${tile}_${idx}`)
            }
          }, (meld: number[]) => `my_meld_${meld[0]}`)
        }
        .height(30)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 2 })
      }

      Row({ space: 0 }) {
        Column({ space: 2 }) {
          Text(gameManager.getPlayerName(0))
            .fontSize(13)
            .fontColor(this.gameState.currentPlayer === 0 ? '#FFD700' : '#ffffff')
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)

          Text(`${this.getSeatHandArray(0).length}张`)
            .fontSize(10)
            .fontColor('#ffffff80')
        }
        .width(48)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 8 })

        Scroll() {
          Row({ space: 2 }) {
            ForEach(this.getNormalHand(0), (tile: number, index: number) => {
              this.buildMainTile(tile, index, this.gameState.currentPlayer === 0)
            }, (tile: number, index: number) => `my_hand_${tile}_${index}_${this.sortedHandVersion}`)

            if (this.getDrawnTile(0) > 0) {
              Blank().width(14)
              this.buildMainTile(this.getDrawnTile(0), 13, this.gameState.currentPlayer === 0)
            }
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .layoutWeight(1)
        .height(64)
      }
      .width('100%')
      .height(76)
      .padding({ left: 12, right: 12, bottom: 8 })
      .backgroundColor(this.gameState.currentPlayer === 0 ? 'rgba(255,215,0,0.12)' : 'rgba(0,0,0,0.2)')
      .borderRadius(8)
      .border({
        width: this.gameState.currentPlayer === 0 ? 2 : 1,
        color: this.gameState.currentPlayer === 0 ? '#FFD70060' : '#ffffff20'
      })
    }
    .width('100%')
    .height(132)
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  buildActionButtons(): void {
    if (!this.waitingForReaction) {
      Row({ space: 8 }) {
        if (this.shouldShowDrawButton()) {
          Button('摸牌')
            .fontSize(13)
            .height(34)
            .width(64)
            .backgroundColor('#4CAF50')
            .fontColor('#fff')
            .borderRadius(6)
            .onClick(() => {
              this.drawTile();
            })
        }

        if (this.shouldShowDiscardButton()) {
          Button(this.selectedTileIndex !== -1 ? '打出' : '选牌')
            .fontSize(13)
            .height(34)
            .width(72)
            .backgroundColor(this.selectedTileIndex !== -1 ? '#2196F3' : '#555')
            .fontColor('#fff')
            .borderRadius(6)
            .enabled(this.selectedTileIndex !== -1)
            .onClick(() => {
              this.discardTile();
            })
        }

        if (this.hasPongAction()) {
          Button('碰')
            .fontSize(13)
            .height(34)
            .width(50)
            .backgroundColor('#9b59b6')
            .fontColor('#fff')
            .borderRadius(6)
            .onClick(() => {
              this.performPongAction();
            })
        }

        if (this.hasKongAction()) {
          Button('杠')
            .fontSize(13)
            .height(34)
            .width(50)
            .backgroundColor('#f39c12')
            .fontColor('#fff')
            .borderRadius(6)
            .onClick(() => {
              this.performKongAction();
            })
        }

        if (this.hasWinAction()) {
          Button('胡')
            .fontSize(13)
            .height(34)
            .width(50)
            .backgroundColor('#e74c3c')
            .fontColor('#fff')
            .borderRadius(6)
            .onClick(() => {
              this.performWinAction();
            })
        }
      }
      .width('100%')
      .height(38)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 2, bottom: 2 })
    }
  }

  @Builder
  buildReactionOverlay(): void {
    Column({ space: 12 }) {
      Text(`${gameManager.getPlayerName(this.discardedBy)} 打出 ${this.getTileText(this.discardedTile)}`)
        .fontSize(14)
        .fontColor('#FF9800')
        .fontWeight(FontWeight.Bold)

      Row({ space: 10 }) {
        if (this.hasWinAction()) {
          Button('胡')
            .fontSize(16)
            .height(48)
            .width(72)
            .backgroundColor('#e74c3c')
            .fontColor('#fff')
            .borderRadius(8)
            .onClick(() => {
              this.performWinAction();
            })
        }

        if (this.hasKongAction()) {
          Button('杠')
            .fontSize(16)
            .height(48)
            .width(72)
            .backgroundColor('#f39c12')
            .fontColor('#fff')
            .borderRadius(8)
            .onClick(() => {
              this.performKongAction();
            })
        }

        if (this.hasPongAction()) {
          Button('碰')
            .fontSize(16)
            .height(48)
            .width(72)
            .backgroundColor('#3498db')
            .fontColor('#fff')
            .borderRadius(8)
            .onClick(() => {
              this.performPongAction();
            })
        }

        Button('过')
          .fontSize(16)
          .height(48)
          .width(72)
          .backgroundColor('rgba(255,255,255,0.2)')
          .fontColor('#fff')
          .borderRadius(8)
          .onClick(() => {
            this.performReaction(0, 'PASS');
          })
      }
    }
    .padding(16)
    .backgroundColor('rgba(0,0,0,0.75)')
    .borderRadius(12)
    .border({ width: 1, color: '#FFD70040' })
    .shadow({ radius: 20, color: '#00000080' })
  }

  @Builder
  buildHiddenTile(): void {
    Stack() {
      Rect()
        .width(20)
        .height(26)
        .fill('#00000030')
        .offset({ x: 1, y: 1 })
        .borderRadius(2)

      Rect()
        .width(20)
        .height(26)
        .fill('#1e4d2b')
        .borderRadius(2)
        .border({ width: 1, color: '#143620' })

      Rect()
        .width(14)
        .height(18)
        .fill('#163d22')
        .borderRadius(1)

      Rect()
        .width(5)
        .height(5)
        .fill('#0f2e19')
        .borderRadius(2.5)
    }
    .width(20)
    .height(26)
  }

  @Builder
  buildMiniTile(tile: number): void {
    Stack() {
      Rect()
        .width(20)
        .height(28)
        .fill('#00000020')
        .offset({ x: 1, y: 1 })
        .borderRadius(2)

      Rect()
        .width(20)
        .height(28)
        .fill('#f5f5dc')
        .borderRadius(2)
        .border({ width: 1, color: '#333333' })

      Image($rawfile(this.getTileImagePath(tile)))
        .width(16)
        .height(22)
        .objectFit(ImageFit.Contain)
    }
    .width(20)
    .height(28)
  }

  @Builder
  buildMainTile(tile: number, index: number, selectable: boolean): void {
    Stack() {
      Rect()
        .width(36)
        .height(52)
        .fill('#00000040')
        .offset({ x: 2, y: 2 })
        .borderRadius(3)

      Rect()
        .width(36)
        .height(52)
        .fill('#f5f5dc')
        .borderRadius(3)
        .border({ width: 1.5, color: '#2c2c2c' })

      Image($rawfile(this.getTileImagePath(tile)))
        .width(30)
        .height(42)
        .objectFit(ImageFit.Contain)

      if (this.selectedTileIndex === index && this.gameState.currentPlayer === 0) {
        Rect()
          .width(38)
          .height(54)
          .fill('transparent')
          .border({ width: 2.5, color: '#FFD700' })
          .borderRadius(4)
      }
    }
    .width(36)
    .height(54)
    .offset({ y: (this.selectedTileIndex === index && this.gameState.currentPlayer === 0) ? -10 : 0 })
    .zIndex((this.selectedTileIndex === index && this.gameState.currentPlayer === 0) ? 10 : 1)
    .onClick(() => {
      if (this.gameState.currentPlayer === 0 && this.isCurrentPlayerDiscardable()) {
        this.selectedTileIndex = index;
      }
    })
    // 添加动画过渡效果
    .animation({
      duration: 200,
      curve: Curve.EaseOut
    })
  }

  @Builder
  buildGameOverDialog(): void {
    Column() {
      Text('🎉 游戏结束')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .margin({ bottom: 12 })

      Text(`获胜者: ${this.gameOverWinner}`)
        .fontSize(18)
        .fontColor('#ffffff')
        .margin({ bottom: 16 })

      Scroll() {
        Column() {
          ForEach([0, 1, 2, 3], (seat: number) => {
            Column() {
              Row() {
                Text(gameManager.getPlayerName(seat))
                  .fontSize(14)
                  .fontWeight(seat === this.gameState.winner ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(seat === this.gameState.winner ? '#FFD700' : '#fff')

                Blank()

                Text(`${this.gameOverScores[seat] || 0} 分`)
                  .fontSize(14)
                  .fontColor((this.gameOverScores[seat] || 0) > 0 ? '#4CAF50' : '#f44336')
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')
              .margin({ bottom: 4 })

              if (this.getSeatMeldsArray(seat).length > 0) {
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  ForEach(this.getSeatMeldsArray(seat), (meld: number[]) => {
                    Row({ space: 1 }) {
                      ForEach(meld, (tile: number, idx: number) => {
                        this.buildMiniTile(tile)
                      }, (tile: number, idx: number) => `go_meld_${seat}_${meld[0]}_${idx}`)
                    }
                    .margin({ right: 4, bottom: 2 })
                  }, (meld: number[]) => `go_meld_section_${seat}_${meld.join(',')}`)
                }
                .margin({ bottom: 4 })
              }

              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.getSeatHandArray(seat), (tile: number, index: number) => {
                  this.buildMiniTile(tile)
                }, (tile: number, index: number) => `go_hand_${seat}_${tile}_${index}`)
              }
            }
            .width('100%')
            .padding(8)
            .margin({ bottom: 6 })
            .backgroundColor(seat === this.gameState.winner ? 'rgba(255,215,0,0.12)' : 'rgba(255,255,255,0.05)')
            .borderRadius(8)
            .border({ width: 1, color: seat === this.gameState.winner ? '#FFD70040' : '#ffffff15' })
          }, (seat: number) => `go_player_${seat}`)
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .height(280)
      .width('100%')
      .margin({ bottom: 16 })

      Row({ space: 12 }) {
        Button('再来一局')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .backgroundColor('rgba(255,255,255,0.15)')
          .fontColor('#ffffffcc')
          .borderRadius(22)
          .onClick(() => {
            this.showGameOver = false;
            networkManager.send('SINGLE_PLAYER_START', { type: 'SINGLE_PLAYER_START' });
          })

        Button('返回大厅')
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .backgroundColor('#4CAF50')
          .fontColor('#fff')
          .borderRadius(22)
          .onClick(() => {
            networkManager.disconnect();
            gameManager.reset();
            try {
              router.back();
            } catch (e) {
              console.error('Router back error:', JSON.stringify(e));
            }
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(20)
    .backgroundColor('rgba(26,26,46,0.97)')
    .borderRadius(16)
    .border({ width: 2, color: '#FFD700' })
    .shadow({ radius: 30, color: '#00000080' })
  }

  // ==================== build() 主入口 ====================

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 0 }) {
        this.buildInfoBar()

        Column({ space: 0 }) {
          this.buildTopPlayer()

          Row({ space: 0 }) {
            this.buildLeftPlayer()
            this.buildCenterArea()
            this.buildRightPlayer()
          }
          .layoutWeight(1)
          .width('100%')

          this.buildBottomPlayer()
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#0d5c2e')

      if (this.waitingForReaction) {
        this.buildReactionOverlay()
      }

      if (this.showGameOver) {
        this.buildGameOverDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 普通方法区 ====================

  private getSeatHandArray(seat: number): number[] {
    return gameManager.getSeatHand(seat);
  }

  private getSeatMeldsArray(seat: number): number[][] {
    return gameManager.getSeatMelds(seat);
  }

  private getSeatDiscardedArray(seat: number): number[] {
    const discards = this.gameState.allDiscarded.get(seat);
    return discards || [];
  }

  private getNormalHand(seat: number): number[] {
    const hand = this.getSeatHandArray(seat);
    let normalHand: number[];
    if (seat === 0 && hand.length >= 14) {
      normalHand = hand.slice(0, 13);
    } else {
      normalHand = hand;
    }
    // 玩家0的手牌进行排序（相同牌放在一起）
    if (seat === 0) {
      return sortHandTiles(normalHand);
    }
    return normalHand;
  }

  private getDrawnTile(seat: number): number {
    const hand = this.getSeatHandArray(seat);
    if (seat === 0 && hand.length >= 14) {
      return hand[13];
    }
    return 0;
  }

  private isCurrentPlayerDiscardable(): boolean {
    if (this.waitingForReaction) return false;
    return this.shouldShowDiscardButton();
  }

  private shouldShowDrawButton(): boolean {
    // 只有轮到玩家自己时才显示摸牌按钮
    if (this.gameState.currentPlayer !== 0) return false;
    const hand = this.getSeatHandArray(0);
    return hand.length === 13;
  }

  private shouldShowDiscardButton(): boolean {
    // 只有轮到玩家自己时才显示打出按钮
    if (this.gameState.currentPlayer !== 0) return false;
    const hand = this.getSeatHandArray(0);
    return hand.length >= 14 || hand.length < 13;
  }

  getTileColor(tileId: number): string {
    return gameManager.getTileColor(tileId);
  }

  private showActionToast(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 1500 });
    } catch (e) {
      console.error('Show toast error:', JSON.stringify(e));
    }
  }

  getTileText(tileId: number): string {
    return gameManager.getTileDisplayText(tileId);
  }

  getTileImagePath(tileId: number): string {
    const tileInfo = gameManager.getTileInfo(tileId);
    if (!tileInfo) {
      return 'wan/一万.png';
    }

    const value = tileInfo.value;
    const numberNames = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

    switch (tileInfo.type) {
      case 0: // 万
        return `wan/${numberNames[value - 1]}万.png`;
      case 1: // 条
        return `tiao/${numberNames[value - 1]}条.png`;
      case 2: // 筒
        return `tong/${numberNames[value - 1]}筒.png`;
      default:
        return 'wan/一万.png';
    }
  }

  getCurrentTurnText(): string {
    if (this.waitingForReaction) {
      return '等待反应...';
    }
    const name = gameManager.getPlayerName(this.gameState.currentPlayer);
    return `${name}的回合`;
  }

  private setupNetworkListeners(): void {
    networkManager.on('SINGLE_PLAYER_ACTION_CONFIRM', (msg: MessageData) => {
      console.info('单人动作确认:', JSON.stringify(msg));
      if (msg.accepted === false) {
        try {
          promptAction.showToast({ message: '操作无效' });
        } catch (e) {
          console.error('Show toast error:', JSON.stringify(e));
        }
        return;
      }

      gameManager.updateServerSinglePlayerState(msg);
      this.selectedTileIndex = -1;

      if (msg.selfDrawWinAvailable !== undefined) {
        this.selfDrawWinAvailable = msg.selfDrawWinAvailable === true;
      } else {
        this.selfDrawWinAvailable = false;
      }

      if (msg.selfDrawKongAvailable !== undefined) {
        this.selfDrawKongAvailable = msg.selfDrawKongAvailable === true;
      } else {
        this.selfDrawKongAvailable = false;
      }

      if (msg.waitingForReaction === true) {
        this.waitingForReaction = true;
        this.discardedTile = Number(msg.discardedTile) || 0;
        this.discardedBy = Number(msg.discardedBy) || -1;
        const reactions = msg.reactions;
        if (reactions) {
          this.availableReactions = new Map();
          const keys = Object.keys(reactions);
          for (let i = 0; i < keys.length; i++) {
            const seat = parseInt(keys[i]);
            if (!isNaN(seat)) {
              this.availableReactions.set(seat, reactions[keys[i]] as string[]);
            }
          }
        }
        if (this.availableReactions.size === 0) {
          setTimeout(() => {
            this.performReaction(0, 'PASS');
          }, 300);
        }
      } else {
        this.waitingForReaction = false;
        this.availableReactions.clear();
        this.discardedBy = -1;
      }
    });

    networkManager.on('SINGLE_PLAYER_STATE_PUSH', (msg: MessageData) => {
      console.info('收到AI回合结束推送:', JSON.stringify(msg));
      gameManager.updateServerSinglePlayerState(msg);

      const lastAction = msg.lastAction as string;
      const lastActionSeat = Number(msg.lastActionSeat);
      if (lastAction && !isNaN(lastActionSeat) && lastActionSeat !== 0) {
        const playerName = gameManager.getPlayerName(lastActionSeat);
        if (lastAction === 'PONG') {
          this.showActionToast(`${playerName} 碰了牌`);
        } else if (lastAction === 'KONG') {
          this.showActionToast(`${playerName} 杠了牌`);
        } else if (lastAction === 'WIN') {
          this.showActionToast(`${playerName} 胡牌了！`);
        }
      }

      if (msg.waitingForReaction === true) {
        this.waitingForReaction = true;
        this.discardedTile = Number(msg.discardedTile) || 0;
        this.discardedBy = msg.discardedBy !== undefined ? Number(msg.discardedBy) : -1;
        const reactions = msg.reactions;
        if (reactions) {
          this.availableReactions = new Map();
          const keys = Object.keys(reactions);
          for (let i = 0; i < keys.length; i++) {
            const seat = parseInt(keys[i]);
            if (!isNaN(seat)) {
              this.availableReactions.set(seat, reactions[keys[i]] as string[]);
            }
          }
        }
      } else {
        this.waitingForReaction = false;
        this.availableReactions.clear();
      }

      if (msg.gameEnded === true) {
        this.handleGameEndMsg(msg);
      }
    });

    networkManager.on('SINGLE_PLAYER_GAME_END', (msg: MessageData) => {
      this.handleGameEndMsg(msg);
    });

    networkManager.on('ERROR', (msg: MessageData) => {
      const message = msg.message ? String(msg.message) : '操作失败';
      try {
        promptAction.showToast({ message: message });
      } catch (e) {
        console.error('Show toast error:', JSON.stringify(e));
      }
    });
  }

  private handleGameEndMsg(msg: MessageData): void {
    console.info('游戏结束消息:', JSON.stringify(msg));

    // 清除反应覆盖层状态，防止与胜利弹窗冲突
    this.waitingForReaction = false;
    this.availableReactions.clear();
    this.discardedBy = -1;

    if (msg.hands || msg.melds || msg.discarded) {
      gameManager.updateServerSinglePlayerState(msg);
    }

    const winner = Number(msg.winner);
    if (winner === -1) {
      this.gameOverWinner = '流局（荒牌）';
    } else {
      this.gameOverWinner = gameManager.getPlayerName(winner);
    }

    const seatScores: Record<number, number> = {};
    const scores = msg.scores;
    if (scores) {
      const keys = Object.keys(scores);
      for (let i = 0; i < keys.length; i++) {
        const playerId = keys[i];
        const match = playerId.match(/seat(\d+)$/);
        if (match) {
          seatScores[parseInt(match[1])] = scores[playerId];
        }
      }
    }
    this.gameOverScores = seatScores;
    this.showGameOver = true;

    console.info(`游戏结束 - 获胜者: ${this.gameOverWinner}, 分数: ${JSON.stringify(seatScores)}`);
  }

  private drawTile(): void {
    networkManager.send('SINGLE_PLAYER_ACTION', {
      type: 'SINGLE_PLAYER_ACTION',
      seat: this.gameState.currentPlayer,
      action: 'DRAW'
    });
  }

  private discardTile(): void {
    if (this.selectedTileIndex === -1) return;
    const hand = this.getSeatHandArray(0);
    const tile = hand[this.selectedTileIndex];
    if (tile === undefined) return;
    
    // 检查打出这张牌后手牌是否为空（获胜判定）
    const willBeEmpty = hand.length === 1;
    
    // 使用动画过渡
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.sortedHandVersion++; // 触发重新排序
    });
    
    networkManager.send('SINGLE_PLAYER_ACTION', {
      type: 'SINGLE_PLAYER_ACTION',
      seat: this.gameState.currentPlayer,
      action: 'DISCARD',
      tile: tile
    });
    this.selectedTileIndex = -1;
    
    // 如果打出最后一张牌，判定获胜
    if (willBeEmpty) {
      console.info('[discardTile] 玩家打出最后一张牌，判定获胜');
    }
  }

  private hasPongAction(): boolean {
    let hasPong = false;
    this.availableReactions.forEach((actions: string[], seat: number) => {
      if (seat === 0 && actions.includes('PONG')) {
        hasPong = true;
      }
    });
    return hasPong;
  }

  private hasKongAction(): boolean {
    let hasKong = false;
    this.availableReactions.forEach((actions: string[], seat: number) => {
      if (seat === 0 && actions.includes('KONG')) {
        hasKong = true;
      }
    });
    if (this.selfDrawKongAvailable) {
      hasKong = true;
    }
    if (this.gameState.currentPlayer === 0 && this.getSeatHandArray(0).length === 14) {
      const hand = this.getSeatHandArray(0);
      const tileCounts = new Map<number, number>();
      hand.forEach((tile: number) => {
        const count = tileCounts.get(tile) || 0;
        tileCounts.set(tile, count + 1);
      });
      tileCounts.forEach((count: number, tile: number) => {
        if (count >= 4) {
          hasKong = true;
        }
      });
    }
    return hasKong;
  }

  private hasWinAction(): boolean {
    let hasWin = false;
    this.availableReactions.forEach((actions: string[], seat: number) => {
      if (seat === 0 && actions.includes('WIN')) {
        hasWin = true;
      }
    });
    if (this.selfDrawWinAvailable) {
      hasWin = true;
    }
    return hasWin;
  }

  private performPongAction(): void {
    this.performReaction(0, 'PONG');
  }

  private performKongAction(): void {
    if (this.gameState.currentPlayer === 0 && this.getSeatHandArray(0).length === 14) {
      const hand = this.getSeatHandArray(0);
      const tileCounts = new Map<number, number>();
      hand.forEach((tile: number) => {
        const count = tileCounts.get(tile) || 0;
        tileCounts.set(tile, count + 1);
      });
      let kongTile = 0;
      tileCounts.forEach((count: number, tile: number) => {
        if (count >= 4 && kongTile === 0) {
          kongTile = tile;
        }
      });
      if (kongTile > 0) {
        networkManager.send('SINGLE_PLAYER_ACTION', {
          type: 'SINGLE_PLAYER_ACTION',
          seat: 0,
          action: 'KONG',
          tile: kongTile
        });
        return;
      }
    }
    this.performReaction(0, 'KONG');
  }

  private performWinAction(): void {
    this.performReaction(0, 'WIN');
  }

  private performReaction(seat: number, action: string): void {
    networkManager.send('SINGLE_PLAYER_ACTION', {
      type: 'SINGLE_PLAYER_ACTION',
      seat: seat,
      action: action,
      tile: this.discardedTile
    });
    this.waitingForReaction = false;
    this.availableReactions.clear();
  }

  private confirmLeave(): void {
    try {
      promptAction.showDialog({
        title: '退出游戏',
        message: '确定要退出当前游戏吗？',
        buttons: [
          { text: '取消', color: '#999' },
          { text: '退出', color: '#e74c3c' }
        ]
      }).then((result: DialogResult) => {
        if (result.index === 1) {
          networkManager.disconnect();
          gameManager.reset();
          try {
            router.back();
          } catch (e) {
            console.error('Router back error:', JSON.stringify(e));
          }
        }
      });
    } catch (e) {
      console.error('Show dialog error:', JSON.stringify(e));
    }
  }
}