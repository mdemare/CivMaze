import SpriteKit

enum Orientation: Int, CaseIterable {
    case left = 0
    case straight = 1
    case right = 2
    case back = 3
}

enum Direction: Int, CaseIterable {
    case north = 0
    case east = 1
    case south = 2
    case west = 3
    
    func turn(_ orientation: Orientation) -> Direction {
        switch orientation {
        case .straight: return self
        case .back: return Direction(rawValue: (rawValue + 2) % 4) ?? .north
        case .right: return Direction(rawValue: (rawValue + 1) % 4) ?? .north
        case .left: return Direction(rawValue: (rawValue + 3) % 4) ?? .north
        }
    }
    
    func vector() -> BoardPosition {
        switch self {
        case .north: return BoardPosition(0, 1)
        case .east: return BoardPosition(1, 0)
        case .south: return BoardPosition(0, -1)
        case .west: return BoardPosition(-1, 0)
        }
    }
}

struct BoardPosition: Equatable {
    let row: Int
    let col: Int
    init(_ col: Int, _ row: Int) {
        self.row = row
        self.col = col
    }
    
    static func ==(lhs: BoardPosition, rhs: BoardPosition) -> Bool {
        return lhs.row == rhs.row && lhs.col == rhs.col
    }
    
    func neighbours() -> [BoardPosition] {
        return Direction.allCases.map { walkIn($0.vector()) }
    }
    
    func direction(_ other: BoardPosition) -> Direction {
        if col == other.col {
            if row > other.row {
                return .south
            } else {
                return .north
            }
        } else {
            if col > other.col {
                return .east
            } else {
                return .west
            }
        }
    }
    
    func walkIn(_ direction: BoardPosition) -> BoardPosition {
        return BoardPosition(direction.col + col, direction.row + row)
    }
    
    func distanceFrom(_ position: BoardPosition) -> Float {
        let dist = sqrt(pow(Float(position.col - col), 2.0) + pow(Float(position.row - row), 2.0))
        return dist
    }
    
    func walkIn(direction: Direction, orientation: Orientation) -> BoardPosition {
        return walkIn(direction.turn(orientation).vector())
    }
}

class City: Equatable {
    let player: Int
    let row: Int
    let col: Int
    let maze: Maze
    let position: BoardPosition
    var gold = 0
    var research = 0
    var food = 0
    var production = 51
    
    init(player: Int, col: Int, row: Int, maze: Maze) {
        self.player = player
        self.col = col
        self.row = row
        self.position = BoardPosition(col, row)
        self.maze = maze
    }
    
    static func ==(lhs: City, rhs: City) -> Bool {
        return lhs.position == rhs.position
    }
    
    func color() -> UIColor {
        if player == 1 {
            return .red
        } else {
            return .blue
        }
    }
    
    func freePosition() -> BoardPosition {
        let positions: [BoardPosition] = position.neighbours()
        if let fpos = positions.shuffled().filter({ maze.isEmpty(pos: $0) }).first {
            return fpos
        } else {
            fatalError("No free position found!")
        }
    }
}

class Warrior {
    let city: City
    var position: BoardPosition
    var direction: Direction = Direction.north
    var sprite: SKSpriteNode?
    var attrition = 0
    var alive: Bool = true

    init(city: City) {
        self.city = city
        self.position = city.freePosition()
        self.direction = city.position.direction(position)
        print("Creating warrior at \(position.col) \(position.row)")
    }
    
    func advance() {
        for orientation in Orientation.allCases {
            let newPos = position.walkIn(direction: direction, orientation: orientation)
            if city.maze.isEmpty(pos: newPos) {
                position = newPos
                direction = direction.turn(orientation)
                return
            }
        }
        fatalError("No orientations worked")
    }
}

class Bullet {
    let city: City
    let warrior: Warrior
    
    init(city: City, warrior: Warrior) {
        self.city = city
        self.warrior = warrior
    }
}

class GameState {
    var cities: [City] = []
    var warriors: [Warrior] = []
    let maze: Maze = Maze()
    var bullets: [Bullet] = []
    
    func tick(_ count: Int) -> Bool {
        if(count % 5 == 0) {
            fire()
        }
        if(count % 2 == 0) {
            move()
        }
        if(count % 10 == 0) {
            produce()
            consume()
            deploy()
        }
        return count % 2 == 0
    }
    
    func fire() {
        for city in cities {
            for warrior in warriors {
                if city != warrior.city && city.position.distanceFrom(warrior.position) < 15 {
                    bullets.append(Bullet(city: city, warrior: warrior))
                    break
                }
            }
        }
    }
    
    func deploy() {
        for city in cities {
            if(city.production > 10) {
                city.production -= 1000
                let warrior = Warrior(city: city)
                warriors.append(warrior)
            }
            break
        }
    }
    
    func move() {
        
    }
    
    func produce() {
        for city in cities {
            city.food += 1
            city.production += 1
            city.gold += 1
            city.research += 1
        }
    }
    
    func consume() {
        
    }
    
    func createCity(player: Int, col: Int, row: Int) {
        let city = City(player: player, col: col, row: row, maze: self.maze)
        cities.append(city)
    }
}
