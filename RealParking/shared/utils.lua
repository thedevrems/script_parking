ResourceName = GetCurrentResourceName()

shallow_copy = function(t)
    if type(t) == "table" then
      local t2 = {}
      for k,v in pairs(t) do
        t2[k] = v
      end
      return t2
    else
      local ts = ""
      ts = ts .. t
      return ts
    end
end

GetGridCell = function(x, y)
    return math.floor(x / Config.GridSize), math.floor(y / Config.GridSize)
end

GetSurroundingGridCells = function(x,y)

    local gridX, gridY = GetGridCell(x,y)

    return {
        {x = gridX    , y = gridY},

        {x = gridX - 1, y = gridY},
        {x = gridX + 1, y = gridY},
        {x = gridX    , y = gridY - 1},
        {x = gridX    , y = gridY + 1},
        
        {x = gridX - 1, y = gridY - 1},
        {x = gridX + 1, y = gridY + 1},
        {x = gridX - 1, y = gridY + 1},
        {x = gridX + 1, y = gridY - 1}
    }
end

GetTrashGridCells = function(oldCells, newCells)
    local trash = {}

    -- Create a set for quick lookup
    local newCellSet = {}
    for _, cell in ipairs(newCells) do
        newCellSet[cell.x .. "," .. cell.y] = true
    end

    -- Find cells that are in oldCells but not in newCells
    for _, cell in ipairs(oldCells) do
        if not newCellSet[cell.x .. "," .. cell.y] then
            table.insert(trash, cell)
        end
    end

    return trash
end


GetGridCellMidpoint = function(gridX, gridY)
    
    return (gridX * Config.GridSize) + (Config.GridSize / 2), (gridY * Config.GridSize) + (Config.GridSize / 2)
end

GetGridCellCorners = function(gridX, gridY)
    return {
        topLeft = {
            x = gridX * Config.GridSize,
            y = gridY * Config.GridSize
        },
        topRight = {
            x = (gridX + 1) * Config.GridSize,
            y = gridY * Config.GridSize
        },
        bottomLeft = {
            x = gridX * Config.GridSize,
            y = (gridY + 1) * Config.GridSize
        },
        bottomRight = {
            x = (gridX + 1) * Config.GridSize,
            y = (gridY + 1) * Config.GridSize
        }
    }
end