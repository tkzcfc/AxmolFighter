
local M = {}

local USE_DRAG_MODE = true
local r1, r2

local inputTextDefaultflags = 0--imgui.ImGuiInputTextFlags.EnterReturnsTrue
local inputTextReadOnlyDefaultflags = imgui.ImGuiInputTextFlags.ReadOnly

local function getValue(node, getter)
    if type(getter) == "function" then
        return getter(node)
    else
        return node[getter]
    end
end

local function setValue(node, setter, value)
    if setter then
        if type(setter) == "function" then
            setter(node, value)
        else
            node[setter] = value
        end
    end
end

function M.renderPropertyStr(node, propertyName, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local flags = inputTextDefaultflags
    if setter == false then
        flags = inputTextReadOnlyDefaultflags
    end

    local value = getValue(node, getter)

    r1, r2 = imgui.inputText(propertyName, value, flags)
    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertyInt(node, propertyName, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local flags = inputTextDefaultflags
    if setter == false then
        flags = inputTextReadOnlyDefaultflags
    end

    local value = getValue(node, getter)

    r1, r2 = imgui.inputInt(propertyName, value, 1, 100, flags)
    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertySliderInt(node, propertyName, min, max, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    r1, r2 = imgui.sliderInt(propertyName, value, min, max)
    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertySliderFloat(node, propertyName, min, max, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    r1, r2 = imgui.sliderFloat(propertyName, value, min, max)
    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertyBool(node, propertyName, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    r1, r2 = imgui.checkbox(propertyName, value)
    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertyController(node, propertyName)
    local len = #node.Controllers

    if len > 0 then
        for i = 1, len do
            local ctrls = node.Controllers[i]
            local ctrlName = ctrls.name
            local ctrl = node:GetController(ctrlName)
            local index = math.floor(ctrl.selectedIndex) + 1
            local page = ctrls.pageCount
            local pageNames = {}
            for k = 0, page - 1 do
                table.insert(pageNames, ctrls:GetPageNameById(k))
            end

            if imgui.beginCombo(ctrlName, pageNames[index]) then
                for k, v in ipairs(pageNames) do
                    local is_selected = index == (k)
                    if imgui.selectable(tostring(k - 1) .. " - " .. v, is_selected) then
                        ctrl.selectedPage = v
                    end
                    if is_selected then
                        imgui.setItemDefaultFocus()
                    end
                end
                imgui.endCombo()
            end
        end
    end
    --if imgui.beginCombo("Controller", 1) then
    --    print(node:GetControllerCount())
    --
    --
    --
    --    --for i = 1, 5 do
    --    --    local is_selected = 1 == i
    --    --    if imgui.selectable(tostring(i), is_selected) then
    --    --        --selected_option_index[0] = i
    --    --    end
    --    --    if is_selected then
    --    --        imgui.setItemDefaultFocus()
    --    --    end
    --    --end
    --    imgui.endCombo()
    --end
end

function M.renderPropertyFloat(node, propertyName, getter, setter, fmt)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    if USE_DRAG_MODE then
        if setter == false then
            r1, r2 = imgui.inputFloat(propertyName, value, -1, -1, fmt or "%.3f", inputTextReadOnlyDefaultflags)
        else
            r1, r2 = imgui.dragFloat(propertyName, value)
        end
    else
        local flags = inputTextDefaultflags
        if setter == false then
            flags = inputTextReadOnlyDefaultflags
        end

        r1, r2 = imgui.inputFloat(propertyName, value, -1, -1, fmt or "%.3f", flags)
    end

    if r1 then
        setValue(node, setter, r2)
    end
end

function M.renderPropertyVec2(node, propertyName, getter, setter, fmt)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)
    local floatN = { value.x, value.y }

    if USE_DRAG_MODE then
        if setter == false then
            r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", inputTextReadOnlyDefaultflags)
        else
            r1, r2 = imgui.dragFloatN(propertyName, floatN)
        end
    else
        local flags = inputTextDefaultflags
        if setter == false then
            flags = inputTextReadOnlyDefaultflags
        end

        r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", flags)
    end

    if r1 then
        setValue(node, setter, { x = r2[1], y = r2[2] })
    end
end

function M.renderPropertyVec3(node, propertyName, getter, setter, fmt)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)
    local floatN = { value.x, value.y, value.z }

    if USE_DRAG_MODE then
        if setter == false then
            r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", inputTextReadOnlyDefaultflags)
        else
            r1, r2 = imgui.dragFloatN(propertyName, floatN)
        end
    else
        local flags = inputTextDefaultflags
        if setter == false then
            flags = inputTextReadOnlyDefaultflags
        end

        r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", flags)
    end

    if r1 then
        setValue(node, setter, { x = r2[1], y = r2[2], z = r2[3] })
    end
end

function M.renderPropertyMargin(node, propertyName, getter, setter, fmt)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)
    local floatN = { value.left, value.right, value.top, value.bottom }

    if USE_DRAG_MODE then
        if setter == false then
            r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", inputTextReadOnlyDefaultflags)
        else
            r1, r2 = imgui.dragFloatN(propertyName, floatN)
        end
    else
        local flags = inputTextDefaultflags
        if setter == false then
            flags = inputTextReadOnlyDefaultflags
        end

        r1, r2 = imgui.inputFloatN(propertyName, floatN, -1, -1, fmt or "%.3f", flags)
    end

    if r1 then
        setValue(node, setter, { left = r2[1], right = r2[2], top = r2[3], bottom = r2[4] })
    end
end

function M.renderPropertyColor3B(node, propertyName, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    local floatN = { value.r / 255, value.g / 255, value.b / 255 }
    r1, r2 = imgui.colorEdit3(propertyName, floatN)
    if r1 then
        setValue(node, setter, { r = r2[1] * 255, g = r2[2] * 255, b = r2[3] * 255 })
    end
end

function M.renderPropertyColor4B(node, propertyName, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    local floatN = { value.r / 255, value.g / 255, value.b / 255, value.a / 255 }
    r1, r2 = imgui.colorEdit4(propertyName, floatN)
    if r1 then
        setValue(node, setter, { r = r2[1] * 255, g = r2[2] * 255, b = r2[3] * 255, a = r2[4] * 255 })
    end
end

function M.renderPropertyResourceData(node, propertyName, getter)
    if getter == nil then getter = propertyName end

    local value = getValue(node, getter)

    -- plist
    if value.type == 1 then
        imgui.inputText(propertyName .. "(spriteFrame)", value.file, imgui.ImGuiInputTextFlags.ReadOnly)
        if value.plist ~= "" then
            imgui.inputText(propertyName .. "(plist)", value.plist, imgui.ImGuiInputTextFlags.ReadOnly)
        end
    else
        imgui.inputText(propertyName, value.file, imgui.ImGuiInputTextFlags.ReadOnly)
    end
end

function M.renderPropertyOption(node, propertyName, options, getter, setter)
    if getter == nil then getter = propertyName end
    if setter == nil then setter = propertyName end

    local value = getValue(node, getter)

    local index = -1
    local ops = {}
    for k, v in pairs(options) do
        if v[2] == value then
            index = k - 1
        end
        ops[k] = v[1]
    end

    r1, r2 = imgui.combo(propertyName, index, ops)
    if r1 then
        r2 = r2 + 1
        if options[r2] then
            setValue(node, setter, options[r2][2])
        end
    end
end

function M.renderSpriteTooltip(text, sprite)
    imgui.textDisabled(text)
    if imgui.isItemHovered() then
        imgui.beginTooltip()
        if sprite:getTexture() then
            local rect = sprite:getTextureRect()
            if rect.width <= 0 or rect.height <= 0 then
                imgui.text("Empty Texture")
            else
                local showSize = { x = rect.width, y = rect.height }

                local maxHeight = 720
                if showSize.y > maxHeight then
                    local scale = maxHeight / showSize.y
                    showSize.x = showSize.x * scale
                    showSize.y = showSize.y * scale
                end

                imgui.text(string.format("%d x %d", rect.width, rect.height))
                imgui.image(sprite, showSize, true)
            end
        else
            imgui.text("Empty Texture")
        end
        imgui.endTooltip()
    end
end

return M
