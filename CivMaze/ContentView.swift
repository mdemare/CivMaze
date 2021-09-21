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
    static let IPAD = UIDevice.current.userInterfaceIdiom == .pad
    static let COL_COUNT = IPAD ? 49 : 21
    // ipad 1194x834 pt 2x
    // iphone 375x812 pt 3x
    static let ROW_COUNT = 37
    static let WIDTH = IPAD ? 1194 : 375
    static let HEIGHT = IPAD ? 834 : 812
    static let COL_OFFSET = (WIDTH - COL_COUNT * 16) / 2
    static let ROW_OFFSET = (HEIGHT - ROW_COUNT * 16) / 2
    var terrainAtlas: SKTextureAtlas?
    var warriorAtlas: SKTextureAtlas?
    var wallTexture: SKTexture?
    var cityTexture: SKTexture?
    var warriorFrames = [SKTexture]()
    
    override func didMove(to view: SKView) {
        self.physicsWorld.contactDelegate = self
        terrainAtlas = SKTextureAtlas(named: "Sprites")
        warriorAtlas = SKTextureAtlas(named: "man")
        
        if let atlas = warriorAtlas {
            for name in atlas.textureNames.sorted() {
                warriorFrames.append(atlas.textureNamed(name))
            }
        }
        print("terrain = \(terrainAtlas?.textureNames[0] ?? "NOTHING FOUND")")
        wallTexture = terrainAtlas?.textureNamed("sprite_0112")
        cityTexture = terrainAtlas?.textureNamed("sprite_0454")
        let maze = state.maze
        for row in (0 ..< GameScene.ROW_COUNT) {
            for col in (0 ..< GameScene.COL_COUNT) {
                if !maze.isEmpty(pos: BoardPosition(col, row)) {
                    addWall(col, row)
                }
            }
        }
        
        addCity(id: 1, texture: cityTexture, col: GameScene.IPAD ? 25 : 15, row: 21)
        addCity(id: 2, texture: cityTexture, col: 13, row: 9)
        
        
        let sprite = SKSpriteNode(color: UIColor.purple, size: CGSize(width: 100.0, height: 200.0))
        sprite.position = CGPoint(x: 77, y: 553)
        addChild(sprite)
        let sprite2 = SKSpriteNode(color: UIColor.systemPink, size: CGSize(width: 100.0, height: 200.0))
        sprite2.position = CGPoint(x: 177, y: 555)
        addChild(sprite2)
        // everything below y=78 is invisible
        // left edge starts at x=77
        // top is y=553

        gameTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
    }
    
    func addCity(id: Int, texture: SKTexture?, col: Int, row: Int) {
        state.createCity(player: id, col: col, row: row)
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 16, height: 16))
        sprite.position = CGPoint(x: colToX(col), y: rowToY(row))
        addChild(sprite)
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
                let sprite = addSprite(UIColor.lightGray, CGSize(width: 4, height: 4), bullet.city.col, bullet.city.row)
                sprite.zPosition = 999
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
                let didChangeDirection = warrior.advance()
                let matchingCities = state.cities.filter { $0.position == warrior.position && ($0 != warrior.city) }
                if matchingCities.count == 0 {
                    let col = warrior.position.col
                    let row = warrior.position.row
                    let x = colToX(col)
                    let y = rowToY(row)
//                    print("MOVE (\(x), \(y)), (\(col), \(row)), Y POS \(sprite.position.y)")
                    let action = SKAction.move(to: CGPoint(x: x, y: y), duration: 0.2)
                    if didChangeDirection {
                        sprite.removeAction(forKey: "animation")
                        let range = warrior.direction.warriorAnimationRange()
                        sprite.run(SKAction.repeatForever(SKAction.animate(with: Array(warriorFrames[range]), timePerFrame: 0.2)), withKey: "animation")
                    }
                    sprite.run(action)
                } else {
                    sprite.removeFromParent()
                    warrior.sprite = nil
                }
            } else {
                let sprite = addWarriorSprite(warrior, warrior.city.color(), CGSize(width: 10, height: 10), warrior.position.col, warrior.position.row)
                sprite.run(SKAction.repeatForever(SKAction.animate(with: Array(warriorFrames[0..<4]), timePerFrame: 0.2)), withKey: "animation")
                sprite.physicsBody = SKPhysicsBody(circleOfRadius: 10)
                sprite.physicsBody?.categoryBitMask = 1
                sprite.physicsBody?.isDynamic = false
                
            }
        }
        state.warriors = state.warriors.filter { $0.sprite != nil && $0.alive }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask == 3 {
            if let sprite = contact.bodyA.node as? WarriorSprite {
                let bulletSprite = contact.bodyB.node as! SKSpriteNode
                state.hit(warrior: sprite.warrior!)
                bulletSprite.run(SKAction.sequence([SKAction.playSoundFileNamed("bullet2", waitForCompletion: false), SKAction.removeFromParent()]))
            } else if let sprite = contact.bodyB.node as? WarriorSprite {
                let bulletSprite = contact.bodyA.node as! SKSpriteNode
                bulletSprite.run(SKAction.sequence([SKAction.playSoundFileNamed("bullet2", waitForCompletion: false), SKAction.removeFromParent()]))
                state.hit(warrior: sprite.warrior!)
            }
        }
    }
    
    func addWall(_ col: Int, _ row: Int) {
        let sz = CGSize(width: 16, height: 16)
        let sprite = SKSpriteNode(texture: self.wallTexture, size: sz)
        let x = colToX(col)
        let y = rowToY(row)
//        print("SPRITE (\(x), \(y)), (\(col), \(row))")
        sprite.position = CGPoint(x: x, y: y)
        addChild(sprite)
    }
    
    @discardableResult
    func addSprite(_ color: UIColor, _ size: CGSize, _ col: Int, _ row: Int) -> SKSpriteNode {
        let sprite = SKSpriteNode(color: color, size: size)
        let x = colToX(col)
        let y = rowToY(row)
//        print("SPRITE (\(x), \(y)), (\(col), \(row))")
        sprite.position = CGPoint(x: x, y: y)
        addChild(sprite)
        return sprite
    }
    
    func addWarriorSprite(_ warrior: Warrior?, _ color: UIColor, _ size: CGSize, _ col: Int, _ row: Int) -> SKSpriteNode {
        let sprite = WarriorSprite(imageNamed: "man_00")
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
        let col = xToCol(Int(location.x))
        let row = yToRow(Int(location.y))
        print("col: \(col), row: \(row)")
    }
}

struct ContentView: View {
    var scene: SKScene {
        let scene = GameScene()
        scene.scaleMode = .aspectFit
        scene.size = CGSize(width: GameScene.WIDTH, height: GameScene.HEIGHT)
        scene.backgroundColor = .black
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .background(Color.red)
            .frame(width: CGFloat(GameScene.WIDTH), height: CGFloat(GameScene.HEIGHT), alignment: .center)
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

    }
}
