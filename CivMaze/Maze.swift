import Foundation

class Maze {
    var mazeData: [[Character]]
    var colCount = 0
    var rowCount = 0
    var crossroads: [BoardPosition] = []
    
    class func linesFromResourceForced() -> [[Character]] {
        if let path = Bundle.main.path(forResource: "maze", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                return data.components(separatedBy: .newlines).filter { $0.count > 0 }.map { Array($0) }
            } catch {
                print(error)
                return []
            }
        } else {
            return []
        }
    }
    
    init() {
        self.mazeData = Maze.linesFromResourceForced()
        self.colCount = GameScene.COL_COUNT
        self.rowCount = GameScene.ROW_COUNT
    }
    
    func calculateDistanceTo() {
        for col in (0 ..< colCount) {
            for row in (0 ..< rowCount) {
                let pos = BoardPosition(col, row)
                if isEmpty(pos: pos) && pos.neighbours().filter({ isEmpty(pos: $0) }).count > 2 {
                    crossroads.append(pos)
                }
            }
        }
    }
    
    func isEmpty(pos: BoardPosition) -> Bool {
        let row = mazeData[pos.row]
        let cell = row[pos.col]
        return cell != "#"
    }
}
