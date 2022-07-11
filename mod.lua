blt.forcepcalls(true)

if not msim then

	_G.msim = {}

	msim.mod_path = ModPath
	msim.save_path = SavePath
	msim.settings = {
		pp = 73,
		pprr = 15,
		propsmax = 3,
		propsownedcount = 1,
		propsowned = {
			"template"
		},
		propsavailablecount = 3,
		propsavailable = {
			"nightclub",
			"jewstore",
			"yacht"
		},
		keys = {
			menu = "f8"
		}
	}

	RATIO = 150

	function msim:save(f)
		local file = io.open(self.save_path .. "msim_settings.txt", "w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
		end
	end

	function msim:load()
		local file = io.open(self.save_path .. "msim_settings.txt", "r")
		if file then
			local data = json.decode(file:read("*all"))
			file:close()
			for k, v in pairs(data) do
				self.settings[k] = v
			end
		end
	end

	function msim:check_create_menu()

		if self.menu then
			return
		end

		self:load()

		self.menu_title_size = 22
		self.menu_items_size = 18
		self.menu_padding = 16
		self.menu_background_color = Color.black:with_alpha(0.75)
		self.menu_accent_color = BeardLib.Options:GetValue("MenuColor"):with_alpha(0.75)
		self.menu_highlight_color = self.menu_accent_color:with_alpha(0.075)
		self.menu_grid_item_color = Color.black:with_alpha(0.5)

		self.menu = MenuUI:new({
			name = "msimMenu",
			layer = 1000,
			background_blur = true,
			animate_toggle = true,
			text_offset = 3,
			show_help_time = 0.5,
			border_size = 1,
			accent_color = self.menu_accent_color,
			highlight_color = self.menu_highlight_color,
			--localized = true,
			use_default_close_key = true,
			disable_player_controls = true
		})

		local menu_w = self.menu._panel:w()
		local menu_h = self.menu._panel:h()

		self._menu_w_left = menu_w / 3.5 - self.menu_padding
		self._menu_w_right = menu_w - self._menu_w_left - self.menu_padding * 2

		local menu = self.menu:Menu({
			background_color = self.menu_background_color,
			h = self.menu.h,
			auto_height = false
		})

		navbar_font_size = 40
		local navbar = menu:Holder({
			name = "navbar",
			align_method = "grid",
			border_bottom = true,
			border_size = 20,
			inherit_values = {
				size_by_text = true,
				font_size = "35",
				offset = 20,
				full_bg_color = self.menu_background_color
			}
		})

		local pageholder = menu:Holder({
			name = "pageholder",
			scrollbar = true,
			align_method = "centered_grid",
			offset = {50, 10},
			inherit_values = {
				size_by_text = true
			}
		})

		self._pages = {
			props = MSIMPropertyPage:new(self, navbar, pageholder),
			xchange = MSIMExchangePage:new(self, navbar, pageholder),
			stats = MSIMStatisticsPage:new(self, navbar, pageholder),
			options = MSIMOptionsPage:new(self, navbar, pageholder)
		}

		self.msim_logo = navbar:Image({
			name = "msim_logo",
			offset = {0,0},
			w = 512,
			h = 64,
			texture = "textures/icons/msim_logo"
		})

		self.pp_text = navbar:Divider({
			name = "pp_text",
			text = "PP: " ..tostring(msim.settings.pp) .."%",
			offset = 20,
			font_size = navbar_font_size
		})

		self.plus_button = navbar:ImageButton({
			name = "plus_button",
			w = 32,
			h = 32,
			texture = "textures/icons/plus"
		})

	end

	function msim:switch_pages(pagename, item)
		for name, page in pairs(self._pages) do
			page._menu:SetVisible(pagename == name)
			page._button:SetBorder({top = pagename == name})
		end
	end

	function msim:set_menu_state(enabled)
		self:check_create_menu()
		if enabled and not self.menu:Enabled() then
			self.menu:Enable()
		elseif not enabled then
			self.menu:Disable()
		end
	end

	function msim:refresh()
		self.menu:Destroy()
		self.menu = false
		msim:check_create_menu()
		msim:set_menu_state(true)
	end

	function msim:error_message(msg)
		local diag = MenuDialog:new({
			accent_color = self.menu_accent_color,
			highlight_color = self.menu_highlight_color,
			background_color = self.menu_background_color,
			text_offset = {self.menu_padding, self.menu_padding / 4},
			size = self.menu_items_size,
			items_size = self.menu_items_size,
			font_size = 25,
		})
		diag:Show({
			title = "Illegal Action!",
			message = msg,
			w = self.menu._panel:w() / 2,
			title_merge = {
				size = self.menu_title_size
			}})
	end

	function msim:get_actual_value(property)
		local value = tweak_data.msim.properties[property].value
		local min_value = tweak_data.msim.properties[property].min_value
		local money = managers.money:total()
		
		local multiplier = math.round(money / RATIO)
		local newvalue = value * multiplier

		return math.max(newvalue, min_value)
	end

	function msim:make_money_string(price)
		return managers.money._cash_sign .. managers.money:add_decimal_marks_to_string(tostring(price))
	end

	function msim:buy_property(property)
		managers.money:_deduct_from_total(msim:get_actual_value(property), "msim")

		for i, v in ipairs(msim.settings.propsavailable) do
			if v == property then
				table.remove(msim.settings.propsavailable, i, v)
				break
			end
		end

		table.insert(msim.settings.propsowned, 1, property)
		table.sort(msim.settings.propsowned)
		msim.settings.propsownedcount = msim.settings.propsownedcount + 1
		msim.settings.propsavailablecount = msim.settings.propsavailablecount - 1
		self:save()

		msim:refresh()
	end

	function msim:sell_property(property)
		managers.money:_add_to_total(msim:get_actual_value(property), {no_offshore = true}, "msim")

		for i, v in ipairs(msim.settings.propsowned) do
			if v == property then
				table.remove(msim.settings.propsowned, i, v)
				break
			end
		end

		table.insert(msim.settings.propsavailable, 1, property)
		table.sort(msim.settings.propsavailable)
		msim.settings.propsavailablecount = msim.settings.propsavailablecount + 1
		msim.settings.propsownedcount = msim.settings.propsownedcount - 1
		self:save()

		msim:refresh()
	end

	function msim:confirm_prop_transac(property, mode)
		local diag = MenuDialog:new({
			accent_color = self.menu_accent_color,
			highlight_color = self.menu_highlight_color,
			background_color = self.menu_background_color,
			text_offset = {self.menu_padding, self.menu_padding / 4},
			size = self.menu_items_size,
			items_size = self.menu_items_size,
			font_size = 25
		})
		if mode == "buy" then
			diag:Show({
				title = "Confirm Transaction",
				message = "Are you sure you want to buy " .. tweak_data.msim.properties[property].text .. " for " .. msim:make_money_string(msim:get_actual_value(property)) .. "?",
				w = self.menu._panel:w() / 2,
				yes = false,
				title_merge = {
					size = self.menu_title_size
				},
				create_items = function (menu)
					menu:Button({
						text = "dialog_yes",
						text_align = "center",
						localized = true,
						on_callback = function (item)
							if managers.money:total() < msim:get_actual_value(property) then
								diag:hide()
								msim:error_message("Simply a lack of funds")
							else
								diag:hide()
								msim:buy_property(property)
							end
						end
					})
					menu:Button({
						text = "dialog_no",
						text_align = "center",
						localized = true,
						on_callback = function (item)
							diag:hide()
						end
					})
				end
			})
		elseif mode == "sell" then
			diag:Show({
				title = "Confirm Transaction",
				message = "Are you sure you want to sell " .. tweak_data.msim.properties[property].text .. " for " .. msim:make_money_string(msim:get_actual_value(property)) .. "?",
				w = self.menu._panel:w() / 2,
				yes = false,
				title_merge = {
					size = self.menu_title_size
				},
				create_items = function (menu)
					menu:Button({
						text = "dialog_yes",
						text_align = "center",
						localized = true,
						on_callback = function (item)
							diag:hide()
							msim:sell_property(property)
						end
					})
					menu:Button({
						text = "dialog_no",
						text_align = "center",
						localized = true,
						on_callback = function (item)
							diag:hide()
						end
					})
				end
			})
		end
	end

	Hooks:Add("MenuManagerPostInitialize", "MenuManagerPostInitializemsim", function(menu_manager, nodes)

		MenuCallbackHandler.msim_open_menu = function ()
			msim:set_menu_state(true)
		end

		MenuHelperPlus:AddButton({
			id = "msimMenu",
			title = "msim_menu_main_name",
			desc = "msim_menu_main_desc",
			node_name = "main",
			callback = "msim_open_menu",
			position = 8
		})

		local mod = BLT.Mods:GetMod(msim.mod_path:gsub(".+/(.+)/$", "%1"))
		if not mod then
			log("[msim] ERROR: Could not get mod object to register keybinds!")
			return
		end
		BLT.Keybinds:register_keybind(mod, { id = "msim_menu", allow_menu = true, allow_game = true, show_in_menu = false, callback = function()
			msim:set_menu_state(true)
		end }):SetKey(msim.settings.keys.menu)

	end)

end

MSIMPropertyPage = MSIMPropertyPage or class()

function MSIMPropertyPage:init(parent, navbar, pageholder)
	self._button = navbar:Button({
		name = "Properties",
		text = "Properties",
		border_size = 3,
		border_top = true,
		on_callback = ClassClbk(parent, "switch_pages", "props"),
		font_size = navbar_font_size
	})

	self._menu = pageholder:Menu({
		name = "propsholder",
		scrollbar = true,
		auto_height = true
	})

	local ownedheader = self._menu:DivGroup({
		name = "ownedheader",
		text = "Owned Properties",
		align_method = "centered_grid",
		border_bottom = true,
		border_size = 5,
		font_size = 35,
		offset = {0, 0},
		inherit_values = {
			font_size = 35
		}
	})

	local ownedtoolbar = ownedheader:GetToolbar()
	local ownedcount = ownedtoolbar:Divider({
		name = "ownedcount",
		size_by_text = true,
		text = tostring(msim.settings.propsownedcount) .. "/" .. tostring(msim.settings.propsmax) .. " Owned",
		text_align = "right"
	})
	
	for index, prop in ipairs(msim.settings.propsowned) do

		data = tweak_data.msim.properties[prop]

			local ownedprop = self._menu:DivGroup({
			border_bottom = true,
			border_top = true,
			border_right = true,
			border_left = true,
			border_size = 2,
			align_method = "grid",
			font_size = 25,
			offset = {0, 5},
			inherit_values = {
				size_by_text = true,
				font_size = 25,
				align_method = "grid",
			}
		})

		local ownedpropimage = ownedprop:Image({
			name = "ownedpropimage",
			texture = data.texture,
			w = 256,
			h = 128,
			offset = {5, 0},
			icon_w = 256,
			icon_h = 128
		})

		local ownedpropnamevaluegroup = ownedprop:DivGroup({
			name = "ownedpropnamevaluegroup",
			text = data.text,
			w = 512,
			h = 128,
			offset = {5, 0},
			inherit_values = {
				size_by_text = false,
				w = 256
			}
		})

		local ownedpropvalue = ownedpropnamevaluegroup:Divider({
			name = "ownedpropvalue",
			text = "Value: " .. msim:make_money_string(msim:get_actual_value(prop)),
			font_size = 27
		})

		local sellbutton = ownedpropnamevaluegroup:ImageButton({
			name = "sellbutton",
			texture = "textures/icons/sell",
			w = 64,
			h = 64,
			on_callback = ClassClbk(parent, "confirm_prop_transac", prop, "sell")
		})

		local ownedpropfeature = ownedprop:Divider({
			name = "ownedpropfeature",
			text = data.feature,
			text_align = "center",
			font_size = 30
		})
	end

	local availableheader = self._menu:DivGroup({
		name = "availableheader",
		text = "Available Properties",
		align_method = "centered_grid",
		border_bottom = true,
		border_size = 5,
		font_size = 35,
		offset = {0, 10},
		inherit_values = {
			font_size = 35
		}
	})
	
	local availabletoolbar = availableheader:GetToolbar()
	local availablecount = availabletoolbar:Divider({
		name = "availablecount",
		size_by_text = true,
		offset = {0, 0},
		text = tostring(msim.settings.propsavailablecount) .. " Available",
		text_align = "right"
	})
	
	
	for index, prop in ipairs(msim.settings.propsavailable) do

		data = tweak_data.msim.properties[prop]

			local availableprop = self._menu:DivGroup({
			border_bottom = true,
			border_top = true,
			border_right = true,
			border_left = true,
			border_size = 2,
			align_method = "grid",
			font_size = 25,
			offset = {0, 5},
			inherit_values = {
				size_by_text = true,
				font_size = 25,
				align_method = "grid",
			}
		})
	
		local availablepropimage = availableprop:Image({
			name = "availablepropimage",
			texture = data.texture,
			w = 256,
			h = 128,
			offset = {5, 0},
			icon_w = 256,
			icon_h = 128
		})
	
		local availablepropnamevaluegroup = availableprop:DivGroup({
			name = "availablepropnamevaluegroup",
			text = data.text,
			w = 512,
			h = 128,
			offset = {5, 0},
			inherit_values = {
				size_by_text = false,
				w = 256
			}
		})
	
		local availablepropvalue = availablepropnamevaluegroup:Divider({
			name = "availablepropvalue",
			text = "Value: " .. msim:make_money_string(msim:get_actual_value(prop)),
			font_size = 27
		})

		local buybutton = availablepropnamevaluegroup:ImageButton({
			name = "buybutton",
			texture = "textures/icons/buy",
			w = 64,
			h = 64,
			on_callback = ClassClbk(parent, "confirm_prop_transac", prop, "buy")
		})
	
		local availablepropfeature = availableprop:Divider({
			name = "availablepropfeature",
			text = data.feature,
			text_align = "center",
			font_size = 30
		})
	end

end

MSIMExchangePage = MSIMExchangePage or class()

function MSIMExchangePage:init(parent, navbar, pageholder)
	self._button = navbar:Button({
		name = "Exchange",
		text = "Exchange",
		border_size = 3,
		on_callback = ClassClbk(parent, "switch_pages", "xchange"),
		font_size = navbar_font_size
	})

	self._menu = pageholder:Menu({
		name = "xchangeholder",
		scrollbar = true,
		auto_height = true,
		visible = "false"
	})
end

MSIMStatisticsPage = MSIMStatisticsPage or class()

function MSIMStatisticsPage:init(parent, navbar, pageholder)
	self._button = navbar:Button({
		name = "Statistics",
		text = "Statistics",
		border_size = 3,
		on_callback = ClassClbk(parent, "switch_pages", "stats"),
		font_size = navbar_font_size
	})

	self._menu = pageholder:Menu({
		name = "statsholder",
		scrollbar = true,
		auto_height = true,
		visible = "false"
	})
end

MSIMOptionsPage = MSIMOptionsPage or class()

function MSIMOptionsPage:init(parent, navbar, pageholder)
	self._button = navbar:Button({
		name = "Options",
		text = "Options",
		border_size = 3,
		on_callback = ClassClbk(parent, "switch_pages", "options"),
		font_size = navbar_font_size
	})

	self._menu = pageholder:Menu({
		name = "optionsholder",
		scrollbar = true,
		auto_height = true,
		visible = "false"
	})
end