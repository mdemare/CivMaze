import SpriteKit
import SwiftUI

class WarriorSprite: SKSpriteNode {
    var warrior: Warrior? = nil
}

// A simple game scene with falling boxes
class GameScene: SKScene, SKPhysicsContactDelegate {
    var gameTimer: Timer?
    var count = 0
    let state = GameState()
    static let IPAD = false
    static let COL_COUNT = IPAD ? 49 : 21
    // ipad 1194x834 pt 2x
    // iphone 375x812 pt 3x
    static let ROW_COUNT = 37
    static let WIDTH = IPAD ? 1194 : 375
    static let HEIGHT = IPAD ? 834 : 812
    static let COL_OFFSET = (WIDTH - COL_COUNT * 16) / 2
    static let ROW_OFFSET = (HEIGHT - ROW_COUNT * 16) / 2
    
    override func didMove(to view: SKView) {
        self.physicsWorld.contactDelegate = self
        let sz = CGSize(width: 16, height: 16)
        let maze = state.maze
        for i in (0 ..< GameScene.ROW_COUNT) {
            let line = maze.mazeData[i]
            for j in (0 ..< GameScene.COL_COUNT) {
                if line[j] == "#" {
                    addSprite(SKColor.brown, sz, j, i)
                }
            }
        }
        /*
        addSprite(SKColor.red, CGSize(width: 16, height: 16), 36, 27)
        addSprite(SKColor.blue, CGSize(width: 16, height: 16), 13, 9)
        state.createCity(player: 1, col: 36, row: 27)
        state.createCity(player: 2, col: 13, row: 9)
        gameTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
        let c1 = addWarriorSprite(nil, SKColor.green, CGSize(width: 16, height: 16), 0, 0)
        c1.run(SKAction.move(to: CGPoint(x: colToX(48), y: rowToY(0)), duration: 5))

        let c2 = addWarriorSprite(nil, SKColor.green, CGSize(width: 16, height: 16), GameScene.COL_COUNT - 1, 0)
        c2.run(SKAction.move(to: CGPoint(x: colToX(0), y: rowToY(0)), duration: 6))
        
        let c3 = addWarriorSprite(nil, SKColor.green, CGSize(width: 16, height: 16), 0, GameScene.ROW_COUNT - 1)
        c3.run(SKAction.move(to: CGPoint(x: colToX(48), y: rowToY(36)), duration: 7))
        
        let c4 = addWarriorSprite(nil, SKColor.green, CGSize(width: 16, height: 16), GameScene.COL_COUNT - 1, GameScene.ROW_COUNT - 1)
        c4.run(SKAction.move(to: CGPoint(x: colToX(0), y: rowToY(36)), duration: 8))
 */
        
    }
    
    @objc func runTimedCode() {
        self.count += 1
        if state.tick(count) {
            renderWarriors()
        }
        renderBullets()
    }
    
    func renderBullets() {
        for bullet in state.bullets {
            if let warriorSprite = bullet.warrior.sprite {
                let sprite = addSprite(UIColor.gray, CGSize(width: 4, height: 4), bullet.city.col, bullet.city.row)
                let action = SKAction.move(to: warriorSprite.position, duration: 0.5)
                let remove = SKAction.removeFromParent()
                let sequence = SKAction.sequence([action, remove])
                sprite.physicsBody = SKPhysicsBody(circleOfRadius: 4)
                sprite.physicsBody?.collisionBitMask = 1
                sprite.physicsBody?.categoryBitMask = 2
                sprite.physicsBody?.contactTestBitMask = 1
                sprite.run(sequence)
            }
        }
        state.bullets = []
    }
    
    func renderWarriors() {
        for warrior in state.warriors.filter({ $0.alive }) {
            if let sprite = warrior.sprite {
                warrior.advance()
                let matchingCities = state.cities.filter { $0.position == warrior.position && ($0 != warrior.city) }
                if matchingCities.count == 0 {
                    let col = warrior.position.col
                    let row = warrior.position.row
                    let x = colToX(col)
                    let y = rowToY(row)
                    print("MOVE (\(x), \(y)), (\(col), \(row)), Y POS \(sprite.position.y)")
                    let action = SKAction.move(to: CGPoint(x: x, y: y), duration: 0.2)
                    sprite.run(action)
                } else {
                    sprite.removeFromParent()
                    warrior.sprite = nil
                }
            } else {
                let sprite = addWarriorSprite(warrior, warrior.city.color(), CGSize(width: 10, height: 10), warrior.position.col, warrior.position.row)
                sprite.physicsBody = SKPhysicsBody(circleOfRadius: 10)
                sprite.physicsBody?.categoryBitMask = 1
                
            }
        }
        state.warriors = state.warriors.filter { $0.sprite != nil && $0.alive }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask == 3 {
            if let sprite = contact.bodyA.node as? WarriorSprite {
                sprite.removeFromParent()
                sprite.warrior?.sprite = nil
                sprite.warrior?.alive = false
            } else if let sprite = contact.bodyB.node as? WarriorSprite {
                sprite.removeFromParent()
                sprite.warrior?.sprite = nil
                sprite.warrior?.alive = false
            }
        }
    }
    
    func addSprite(_ color: UIColor, _ size: CGSize, _ col: Int, _ row: Int) -> SKSpriteNode {
        let sprite = SKSpriteNode(color: color, size: size)
        let x = colToX(col)
        let y = rowToY(row)
        print("SPRITE (\(x), \(y)), (\(col), \(row))")
        sprite.position = CGPoint(x: x, y: y)
        addChild(sprite)
        return sprite
    }
    
    func addWarriorSprite(_ warrior: Warrior?, _ color: UIColor, _ size: CGSize, _ col: Int, _ row: Int) -> SKSpriteNode {
        let sprite = WarriorSprite(color: color, size: size)
        warrior?.sprite = sprite
        sprite.warrior = warrior
        sprite.position = CGPoint(x: colToX(col), y: rowToY(row))
        addChild(sprite)
        return sprite
    }
    
    func xToCol(_ x: Int) -> Int {
        return (x - GameScene.COL_OFFSET) / 16
    }
    
    func colToX(_ col: Int) -> Int {
        return GameScene.COL_OFFSET + 16 * col
    }

    func yToRow(_ y: Int) -> Int {
        return (y - GameScene.ROW_OFFSET) / 16
    }

    func rowToY(_ row: Int) -> Int {
        return GameScene.ROW_OFFSET + 16 * row
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        print("col: \(xToCol(Int(location.x))), row: \(yToRow(Int(location.y)))")
    }
}

// A sample SwiftUI creating a GameScene and sizing it
// at 300x400 points
struct ContentView: View {
    var scene: SKScene {
        let scene = GameScene()
        scene.size = CGSize(width: 1024, height: 768)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .black
        return scene
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .background(Color.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .background(Color.green)

        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
    }
}
