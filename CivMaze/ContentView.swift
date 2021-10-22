import SpriteKit
import SwiftUI
import AVFoundation

func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func vectorLength(_ vector: CGPoint) -> CGFloat {
    return sqrt(pow(vector.x, 2.0) + pow(vector.y, 2.0))
}

class WarriorSprite: SKSpriteNode {
    var warrior: Warrior? = nil
}

// A simple game scene with falling boxes
class GameScene: SKScene, SKPhysicsContactDelegate {
    static let SPEED = 0.5
    var gameTimer: Timer?
    var count = 0
    let state = GameState()
    static let IPAD = UIDevice.current.userInterfaceIdiom == .pad
    static let MAX_TRAJECTORY: CGFloat = 120
    static let COL_COUNT = IPAD ? 49 : 21
    // ipad 1194x834 pt 2x
    // iphone 375x812 pt 3x
    static let ROW_COUNT = 37
    static let WIDTH: CGFloat = IPAD ? 1194 : 375
    static let HEIGHT: CGFloat = IPAD ? 834 : 812
    static let TILE_SIZE = CGSize(width: 16, height: 16)
    static let COL_OFFSET = (Int(WIDTH) - COL_COUNT * Int(TILE_SIZE.width)) / 2
    static let ROW_OFFSET = (Int(HEIGHT) - ROW_COUNT * Int(TILE_SIZE.height)) / 2
    var terrainAtlas: SKTextureAtlas?
    var warriorAtlas: SKTextureAtlas?
    var wallTexture: SKTexture?
    var cityTexture: SKTexture?
    var warriorFrames = [SKTexture]()
    var tilemap: SKTileMapNode?
    var wallTileGroup: SKTileGroup?
    var wallTileDef: SKTileDefinition?
    var warriorShader: SKShader?
    let sound = URL(fileURLWithPath: Bundle.main.path(forResource: "bullet2", ofType: "wav")!)
    var audioPlayer: AVAudioPlayer?
    
    override func didMove(to view: SKView) {
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: sound)
        } catch {
            fatalError("audioPlayer does not load")
        }
        
        let shaderSource = "void main( void ){vec4 color = texture2D(u_texture, v_tex_coord); float alpha = color.a; vec3 outputColor = color.rgb; if (outputColor.x > 0.4 && outputColor.y < 0.1 && outputColor.z < 0.1) {outputColor = vec3(0.05, 0.44, 0.05); } gl_FragColor = vec4(outputColor, 1.0) * alpha; }"
        warriorShader = SKShader(source: shaderSource)

        view.showsFPS = true
        view.preferredFramesPerSecond = 60
        view.showsNodeCount = true
        if let sv = view.superview {
            if let ssv = sv.superview {
                print("super superview frame: \(ssv.frame)")
                print("super superview bounds: \(ssv.bounds)")
                print("super superview class: \(sv.classForCoder)")
            }
            print("superview frame: \(sv.frame)")
            print("superview bounds: \(sv.bounds)")
            print("superview class: \(sv.classForCoder)")
        }
        print("view frame: \(view.frame)")
        print("view bounds: \(view.bounds)")
        print("view class: \(view.classForCoder)")

        print("scene: \(self.frame)")
        print("scene class: \(self.classForCoder)")

        self.physicsWorld.contactDelegate = self
        terrainAtlas = SKTextureAtlas(named: "Sprites")
        warriorAtlas = SKTextureAtlas(named: "man")
        
        guard let tileset = SKTileSet(named: "tileset") else {
           fatalError("tileset Tile Set not found")
         }
        
        for tg in tileset.tileGroups {
            if tg.name == "Wall" {
                wallTileGroup = tg
            }
        }
        tilemap = SKTileMapNode(tileSet: tileset, columns: GameScene.COL_COUNT, rows: GameScene.ROW_COUNT, tileSize: GameScene.TILE_SIZE)
        if let tm = tilemap {
            tm.position = CGPoint(x: colToX(0), y: rowToY(0))
            tm.anchorPoint = CGPoint(x: 0, y: 0)
            addChild(tm)
            print("FRAME: \(tm.frame)")
            print("MAP SIZE: \(tm.mapSize)")
            print("X SCALE: \(tm.xScale)")
            print("Y SCALE: \(tm.yScale)")
        }
        
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
        
        
        let texture: SKTexture? = terrainAtlas?.textureNamed("overlay")
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: GameScene.WIDTH, height: GameScene.HEIGHT))
        placeSprite(sprite, CGPoint(x: 0, y: 0))
        sprite.blendMode = .multiply
        sprite.zPosition = 9
        

        

        gameTimer = Timer.scheduledTimer(timeInterval: 0.1 / GameScene.SPEED, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
    }
    
    func addCity(id: Int, texture: SKTexture?, col: Int, row: Int) {
        state.createCity(player: id, col: col, row: row)
        let sprite = SKSpriteNode(texture: texture, size: GameScene.TILE_SIZE)
        placeSprite(sprite, CGPoint(x: colToX(col), y: rowToY(row)))
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
                sprite.zPosition = 8
                let col = bullet.city.col
                let row = bullet.city.row
                let cityPosition: CGPoint = CGPoint(x: colToX(col), y: rowToY(row))
                let vector = warriorSprite.position - cityPosition
                let trajectory: CGPoint;
                if vector.x == 0 {
                    // x == 0
                    if vector.y > 0 {
                        trajectory = CGPoint(x: 0, y: GameScene.HEIGHT - cityPosition.y)
                    } else {
                        trajectory = CGPoint(x: 0, y: -cityPosition.y)
                    }
                } else if vector.y < 0 {
                    let ypos = cityPosition.y - vector.y * (cityPosition.x / vector.x)
                    trajectory = CGPoint(x: cityPosition.x, y: ypos)
                   // intersection with x = 0
                } else if vector.y > 0 {
                    let ypos = cityPosition.y + vector.y * (GameScene.WIDTH - cityPosition.x) / vector.x
                    trajectory = CGPoint(x: GameScene.WIDTH - cityPosition.x, y: ypos)
                } else {
                    // y == 0
                    if vector.x > 0 {
                        trajectory = CGPoint(x: GameScene.WIDTH - cityPosition.x, y: 0)
                    } else {
                        trajectory = CGPoint(x: -cityPosition.x, y: 0)
                    }
                }
                let dist = vectorLength(trajectory)
                let scale: CGFloat = dist / GameScene.MAX_TRAJECTORY
                let bulletDestination = trajectory + cityPosition
                print("TRAJECTORY = \(trajectory)")
                print("BULLET DEST = \(bulletDestination)")
                print("SCALE = \(scale)")
                let action = SKAction.move(to: bulletDestination, duration: scale * 0.15 / GameScene.SPEED)
                let remove = SKAction.removeFromParent()
                let sequence = SKAction.sequence([action, remove])
                let pb = SKPhysicsBody(circleOfRadius: 2)
                sprite.physicsBody = pb
                pb.affectedByGravity = false
                pb.collisionBitMask = 1
                pb.categoryBitMask = 2
                pb.contactTestBitMask = 1
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
                    let action = SKAction.move(to: CGPoint(x: x, y: y), duration: 0.2 / GameScene.SPEED)
                    if didChangeDirection {
                        sprite.removeAction(forKey: "animation")
                        let range = warrior.direction.warriorAnimationRange()
                        sprite.run(SKAction.repeatForever(SKAction.animate(with: Array(warriorFrames[range]), timePerFrame: 0.2 / GameScene.SPEED)), withKey: "animation")
                    }
                    sprite.run(action)
                } else {
                    sprite.removeFromParent()
                    warrior.sprite = nil
                }
            } else {
                let sprite = WarriorSprite(imageNamed: "man_00")
                sprite.zPosition = 0
                warrior.sprite = sprite
                sprite.warrior = warrior
                let pb = SKPhysicsBody(circleOfRadius: 4)
                sprite.physicsBody = pb
                pb.categoryBitMask = 1
                pb.isDynamic = false
                sprite.position = CGPoint(x: colToX(warrior.position.col), y: rowToY(warrior.position.row))
                sprite.anchorPoint = CGPoint(x: 0,y: 0)
                addChild(sprite)

                sprite.run(SKAction.repeatForever(SKAction.animate(with: Array(warriorFrames[0..<4]), timePerFrame: 0.2 / GameScene.SPEED)), withKey: "animation")
                
                if warrior.city.player == 2 {
                    sprite.shader = warriorShader!
                }
            }
        }
        state.warriors = state.warriors.filter { $0.sprite != nil && $0.alive }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask == 3 {
            if let sprite = contact.bodyA.node as? WarriorSprite {
                if let bulletSprite = contact.bodyB.node as? SKSpriteNode {
                    let bulletpos = bulletSprite.position
                    let warriorpos = sprite.position
                    // print("bullet at (\(bulletpos.x), \(bulletpos.y)) hits warrior at (\(warriorpos.x), \(warriorpos.y))")
                    state.hit(warrior: sprite.warrior!)
                    DispatchQueue.global().async {
                        self.audioPlayer!.play()
                    }
                    bulletSprite.removeFromParent()
                }
            }
        }
    }
    
    func addWall(_ col: Int, _ row: Int) {
        if let tm = tilemap {
            if let wt = wallTexture {
                let tiledef = SKTileDefinition(texture: wt)
                if let wtg = wallTileGroup {
                    tm.setTileGroup(wtg, andTileDefinition: tiledef, forColumn: col, row: row)
                }
            }
        }
//        let x = colToX(col)
//        let y = rowToY(row)
//        let sprite = SKSpriteNode(texture: self.wallTexture, size: GameScene.TILE_SIZE)
//        placeSprite(sprite, CGPoint(x: x, y: y))
    }
    
    @discardableResult
    func addSprite(_ color: UIColor, _ size: CGSize, _ col: Int, _ row: Int) -> SKSpriteNode {
        let sprite = SKSpriteNode(color: color, size: size)
        let x = colToX(col)
        let y = rowToY(row)
        return placeSprite(sprite, CGPoint(x: x, y: y))
    }
    
    @discardableResult
    func placeSprite(_ sprite: SKSpriteNode, _ position: CGPoint) -> SKSpriteNode {
        sprite.position = position
        sprite.anchorPoint = CGPoint(x: 0,y: 0)
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
        let scene = GameScene(size: CGSize(width: GameScene.WIDTH, height: GameScene.HEIGHT))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .black
        return scene
    }

    var body: some View {
        ZStack {
            EmptyView()
            SpriteView(scene: scene)
                .frame(width: CGFloat(GameScene.WIDTH), height: CGFloat(GameScene.HEIGHT))
                .ignoresSafeArea(.all)
        }
    }
}
