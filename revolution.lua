    --Rotate the pipe based on player direction
    local direction = player:GetMovementDirection()
    local rot = (direction-3) * 90
    local diff = 0
    --lerp angles interpolate the pipe movement to another direction
    if sprite.Rotation < rot then
        diff = -10
        sprite.Rotation = sprite.Rotation + diff
        return
    end
    if sprite.Rotation > rot then
        diff = 10
        sprite.Rotation = sprite.Rotation + diff
        return
    end

    --Broken interpolation
    if direction ~= -1 then
        if sprite.Rotation < rot then
            if(rot-sprite.Rotation > 0) then
                diff = 10
            end
            if(rot-sprite.Rotation < 0) then
                diff = -10
            end
            sprite.Rotation = sprite.Rotation + diff
            return
    end
    end

    --Club Interpolation still pretty broken
    --Rotate the pipe based on player direction
    local direction = player:GetMovementDirection()
    local rot = (direction-3) * 90
    if direction == -1 then
        rot = 0
    end
    local diff = 0
    --find the minimal angle distance between target rotation and sprite rotation
    --rotate the sprite according to the player movement direction
    if(rot-sprite.Rotation > 0) then
        diff = 10
        sprite.Rotation = sprite.Rotation + diff
        return
    end
    if(rot-sprite.Rotation < 0) then
        diff = -10
        sprite.Rotation = sprite.Rotation + diff
        return
    end