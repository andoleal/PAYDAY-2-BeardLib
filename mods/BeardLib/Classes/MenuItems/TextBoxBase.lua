TextBoxBase = TextBoxBase or class()
function TextBoxBase:init(parent, params)
    self._parent = parent
    self.parent = parent.parent
    self.menu = parent.menu
    self.items_size = params.items_size or parent.items_size
	self.panel = params.panel:panel({
		name = "text_panel",
		w = params.w,
		h = params.h or params.items_size,
        layer = 4
	})
	self.panel:set_right(params.panel:w() - 1)
	self.panel:rect({
        name = "line",
		halign = "grow",
		visible = params.line,
        h = 1,
        layer = 2,
        color = params.marker_highlight_color or parent.marker_highlight_color or self.parent.marker_highlight_color,
    }):set_bottom(self.panel:h())
    local text = self.panel:text({
        name = "text",
        text = params.value and (parent.filter == "number" and string.format("%." .. parent.floats .. "f", tonumber(params.value)) or tostring(params.value)) or "",
        align  = params.align,
        wrap = not params.lines or params.lines > 1,
        word_wrap = not params.lines or params.lines > 1,
        h = self.panel:h() - 2,
        color = params.text_color or parent.text_color,
        font = parent.parent.font or "fonts/font_large_mf",
        font_size = self.items_size - 2
    })
    text:set_selection(text:text():len())
    local caret = self.panel:rect({
        name = "caret",
        w = 1,
        visible = false,
        color = text:color():with_alpha(1),
        h = self.items_size - 2,
        layer = 3,
    })
	self.lines = params.lines
	self.btn = params.btn or "0"
    self._before_text = params.text
 	text:enter_text(callback(self, TextBoxBase, "enter_text"))
 	self.update_text = params.update_text or function(self, ...) self._parent:SetValue(...) end
    self:update_caret()
end

function TextBoxBase:CheckText(text)
    if self.filter == "number" then
        if tonumber(text:text()) ~= nil then
            local num = self:tonumber(text:text())
            if self._parent.max or self._parent.min then
                self:update_text(math.clamp(num, self._parent.min or num, self._parent.max or num), true, true)
            else
                self:update_text(num, true, true)
            end
        else
            self:update_text(self:tonumber(self._before_text), true, true)
        end
    else
    	self:update_text(text:text(), true, true)
    end
end

function TextBoxBase:tonumber(text)
    return tonumber(string.format("%." .. self._parent.floats .. "f", (text or 0)))
end

function TextBoxBase:key_hold(text, k)
    local first
    while self.cantype and self.menu._key_pressed == k and (self.menu._highlighted == self._parent or self.menu._openlist == self._parent) do
        local s, e = text:selection()
        local n = utf8.len(text:text())
        if ctrl() then
            if Input:keyboard():down(Idstring("a")) then
                text:set_selection(0, text:text():len())
            elseif Input:keyboard():down(Idstring("c")) then
                Application:set_clipboard(tostring(text:selected_text()))
            elseif Input:keyboard():down(Idstring("v")) then
                if (self.filter == "number" and tonumber(Application:get_clipboard()) == nil) then
                    return
                end
                self._before_text = text:text()
                text:replace_text(tostring(Application:get_clipboard()))
                self.value = self.filter == "number" and tonumber(text:text()) or text:text()
                self:RunCallback()
            elseif Input:keyboard():down(Idstring("z")) and self._before_text then
                local before_text = self._before_text
                self._before_text = text:text()
                self:update_text(before_text, true, true, true)
                self:RunCallback()
            end
        elseif shift() then
            if Input:keyboard():down(Idstring("left")) then
                text:set_selection(s - 1, e)
            elseif Input:keyboard():down(Idstring("right")) then
                text:set_selection(s, e + 1)
            end
        else
            if k == Idstring("backspace") then
                if not (utf8.len(text:text()) < 1) then
                    if s == e and s > 0 then
                        text:set_selection(s - 1, e)
                    end
                    self._before_text = text:text()
                    text:replace_text("")
                    if (self._parent.filter ~= "number") or (text:text() ~= "" and self:fixed_text(text:text()) == text:text()) then
                        self:update_text(text:text(), true, false, true)
                    end
                end
            elseif k == Idstring("left") then
                if s < e then
                    text:set_selection(s, s)
                elseif s > 0 then
                    text:set_selection(s - 1, s - 1)
                end
            elseif k == Idstring("right") then
                if s < e then
                    text:set_selection(e, e)
                elseif s < n then
                    text:set_selection(s + 1, s + 1)
                end
            else
                self.menu._key_pressed = nil
            end
        end
        self:update_caret()
        if not first then
            first = true
            wait(1)
        end
        wait(0.1)
    end
end

function TextBoxBase:fixed_text(text)
	if self._parent.filter == "number" then
		local num = tonumber(text) 
        if num then
		    return string.format("%." .. self._parent.floats .."f", math.clamp(num, self._parent.min or num, self._parent.max or num))
        end
	else
		return text
	end
end

function TextBoxBase:enter_text(text, s)
    local number = self._parent.filter == "number"
    if self.menu._menu_closed or (number and tonumber(s) == nil and s ~= "-" and s ~= ".") then
        return
    end
    if (self.menu._highlighted == self._parent or self.menu._openlist == self._parent) and self.cantype and not Input:keyboard():down(Idstring("left ctrl")) then
        self._before_text = number and (tonumber(text:text()) ~= nil and tonumber(text:text()) or self._before_text) or text:text()
        text:replace_text(s)
        self:update_caret()
        if self:fixed_text(text:text()) == text:text() then
            self:update_text(text:text(), true, false, true)
        end
    end
end

function TextBoxBase:KeyPressed(o, k)
	local text = self.panel:child("text")

 	if k == Idstring("enter") then
 		self.cantype = false
        text:stop()
 		self:CheckText(text)
 	end
     if self.cantype then
        text:stop()
        text:animate(callback(self, self, "key_hold"), k)
        return true
    end
	self:update_caret()
end

function TextBoxBase:update_caret()
	local text = self.panel:child("text")
	local lines = math.max(1,text:number_of_lines())

 	if not self.lines or (self.lines > 1 and self.lines <= lines) then
		self.panel:set_h(self.items_size * lines)
 		self.panel:parent():set_h(self.panel:h())
		text:set_h(self.panel:h())
		self.panel:child("line"):set_bottom(text:h())
	end
	if self._parent.group then
        self._parent.group:AlignItems()
    else
        self.parent:AlignItems()
    end
	local s, e = text:selection()
	local x, y, w, h = text:selection_rect()
    if s == 0 and e == 0 then
        if text:align() == "center" then
            x = text:world_x() + text:w() / 2
        else
            x = text:world_x()
        end
        y = text:world_y()
    end
	self.panel:child("caret"):set_world_position(x, y + 1)
	self.panel:child("caret"):set_visible(self.cantype)
end

function TextBoxBase:MousePressed(button, x, y)
    if not alive(self.panel) then
        return
    end
    local text = self.panel:child("text")
    local cantype = self.cantype
    self.cantype = text:inside(x,y) and button == Idstring(self.btn)
    local could_type = cantype == true and self.cantype == false
    if self.cantype then
        local i = text:point_to_index(x, y)
        self._start_select = i
        self._select_neg = nil
        text:set_selection(i, i)
        self:update_caret()
        return true
    elseif could_type then
    	self:update_text(text:text(), false, true, true)
    	return true
    end
end

function TextBoxBase:MouseMoved(x, y)
    local text = self.panel:child("text")
    if self._start_select then
        local i = text:point_to_index(x, y)
        local s, e = text:selection()
        local old = self._select_neg
        if self._select_neg == nil or (s == e) then
            self._select_neg = (x - self.menu._old_x) < 0
        end
        if self._select_neg then
            text:set_selection(i - 1, self._start_select)
        else
            text:set_selection(self._start_select, i + 1)
        end
    end
    local cantype = self.cantype
    self.cantype = self.panel:inside(x,y) and self.cantype or false
    if cantype and not self.cantype then
        self:CheckText(text)
    end
    self:update_caret()
end

function TextBoxBase:MouseReleased(button, x, y)
    self._start_select = nil
end
