blt.forcepcalls(true)

if not msim then

	_G.msim = {}


	msim.mod_path = ModPath
	msim.save_path = SavePath
	msim.settings = { --initial values
		pp = 100,
		pprr = 15,
		propdiscount = 1,
		propsownedmax = 3,
		propsownedcount = 0,
		propsowned = {
		},
		propsavailablecount = 3,
		propsavailable = {},
		keys = {
			menu = "f8"
		},
		oftsprate = 0.1,
		sptoccrate = 0.0001,
		sptoxprate = 0.01,
	}

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

		self:pick_available_props(3)

		self:load()
		self:save()

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

		navbar_font_size = 37
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
			info = MSIMInformationPage:new(self, navbar, pageholder),
			options = MSIMOptionsPage:new(self, navbar, pageholder)
		}

		self.msim_logo = navbar:Image({
			name = "msim_logo",
			offset = {20,0},
			w = 400,
			h = 64,
			texture = "textures/icons/msim_logo"
		})

		self.pp_text = navbar:Divider({
			name = "pp_text",
			help = "Purchasing Power",
			text = "PP: " ..msim.settings.pp .."%",
			offset = 20,
			font_size = navbar_font_size
		})

		self.pprr_text = navbar:Divider({
			name = "pprr_text",
			help = "Purchasing Power Recovery Rate",
			text = "PPRR: " ..msim.settings.pprr .."%",
			font_size = navbar_font_size
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
		log(property)
		if msim.settings.propsownedcount > 0 then
			local value = tweak_data.msim.properties[property].value
			local min_value = tweak_data.msim.properties[property].min_value
			local money = managers.money:total()
			
			local multiplier = math.round(money / 100)
			local newvalue = value * multiplier

			local newvalue = math.max(newvalue, min_value)
			return newvalue * msim.settings.propdiscount
		else return 0
		end
	end

	function msim:pick_available_props(amount)
		msim.settings.propsavailablecount = amount

		local keys = {}
		local add = true
		for prop, data in pairs(tweak_data.msim.properties) do
			add = true
			for i, v in ipairs(msim.settings.propsowned) do
				if v == prop then
					add = false
				end
			end
			if add then table.insert(keys, 1, prop) end
		end

		msim.settings.propsavailable = {}
		for n = 1, amount do
			local i = math.random(#keys)
			table.insert(msim.settings.propsavailable, 1, keys[i])
			table.remove(keys, i)
		end
	end

	function msim:make_money_string(price)
		return managers.money._cash_sign .. managers.money:add_decimal_marks_to_string(tostring(price))
	end

	function msim:buy_property(property)
		local prop = tweak_data.msim.properties[property]

		if prop.feature == "increase_max_props" then
			msim.settings.propsownedmax = msim.settings.propsownedmax + prop.feature_value
		elseif prop.feature == "increase_oftosp_rate" then
			msim.settings.oftsprate = msim.settings.oftsprate + prop.feature_value / 100
		elseif prop.feature == "increase_sptocc_rate" then
			msim.settings.sptoccrate = msim.settings.sptoccrate + prop.feature_value / 100
		elseif prop.feature == "increase_sptoxp_rate" then
			msim.settings.sptoxprate = msim.settings.sptxprate + prop.feature_value / 100
		elseif prop.feature == "increase_pprr" then
			msim.settings.pprr = msim.settings.pprr + prop.feature_value
		elseif prop.feature == "discount_props" then
			msim.settings.propdiscount = msim.settings.propdiscount - prop.feature_value / 100
		end

		managers.money:_deduct_from_total(msim:get_actual_value(property), "msim")

		for i, v in ipairs(msim.settings.propsavailable) do
			if v == property then
				table.remove(msim.settings.propsavailable, i)
				break
			end
		end

		table.insert(msim.settings.propsowned, 1, property)
		table.sort(msim.settings.propsowned)

		msim.settings.propsownedcount = msim.settings.propsownedcount + 1
		msim.settings.propsavailablecount = msim.settings.propsavailablecount - 1
		msim.settings.pp = msim.settings.pp - prop.value
		self:save()

		msim:refresh()
	end

	function msim:sell_property(property)
		local prop = tweak_data.msim.properties[property]

		if prop.feature == "increase_max_props" then
			if (msim.settings.propsownedmax - prop.feature_value) < (msim.settings.propsownedcount - 1) then
				msim:error_message("Cannot sell property as you have too many others already owned")
				return
			else
				msim.settings.propsownedmax = msim.settings.propsownedmax - prop.feature_value
			end
		elseif prop.feature == "increase_oftosp_rate" then
			msim.settings.oftsprate = msim.settings.oftsprate - prop.feature_value / 100
		elseif prop.feature == "increase_sptocc_rate" then
			msim.settings.sptoccrate = msim.settings.sptoccrate - prop.feature_value / 100
		elseif prop.feature == "increase_sptoxp_rate" then
			msim.settings.sptoxprate = msim.settings.sptxprate - prop.feature_value / 100
		elseif prop.feature == "increase_pprr" then
			msim.settings.pprr = msim.settings.pprr - prop.feature_value
		elseif prop.feature == "discount_props" then
			msim.settings.propdiscount = msim.settings.propdiscount + prop.feature_value / 100
		end

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
				message = "Are you sure you want to buy " .. tweak_data.msim.properties[property].text .. " for " .. msim:make_money_string(msim:get_actual_value(property)) .. "?\nThis will use " .. tweak_data.msim.properties[property].value .. "% of your Purchasing Power (PP).",
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
								msim:error_message("Not enough money!")
							elseif msim.settings.propsownedcount == msim.settings.propsownedmax then
								msim:error_message("You already own the maximum amount of properties!")
							elseif msim.settings.pp < tweak_data.msim.properties[property].value then
								msim:error_message("You don't have enough Purchasing Power (PP)!")
							else
								msim:buy_property(property)
							end
							diag:hide()
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

	function msim:confirm_convert_transac(mode, value1, value2, ppcost)
		ppcost = math.ceil(ppcost)
		value1 = math.floor(value1)
		value2 = math.floor(value2)

		local diag = MenuDialog:new({
			accent_color = self.menu_accent_color,
			highlight_color = self.menu_highlight_color,
			background_color = self.menu_background_color,
			text_offset = {self.menu_padding, self.menu_padding / 4},
			size = self.menu_items_size,
			items_size = self.menu_items_size,
			font_size = 25
		})
		if value1 > 0 and value2 > 0 then
			if mode == "oftosp" then
				diag:Show({
					title = "Confirm Transaction",
					message = "Are you sure you want to convert " .. value1 .. " Offshore Funds to " .. value2 .. " Spending Cash?\nThis will use " .. ppcost .. "% of your Purchasing Power (PP).",
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
								if msim.settings.pp < ppcost then
									msim:error_message("You don't have enough Purchasing Power (PP)!")
								else
									msim:convert_currencies(mode, value1, value2, ppcost)
								end
								diag:hide()
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
			elseif mode == "sptocc" then
				diag:Show({
					title = "Confirm Transaction",
					message = "Are you sure you want to convert " .. value1 .. " Spending Cash to " .. value2 .. " Continental Coins?\nThis will use " .. ppcost .. "% of your Purchasing Power (PP).",
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
								if msim.settings.pp < ppcost then
									msim:error_message("You don't have enough Purchasing Power (PP)!")
								else
									msim:convert_currencies(mode, value1, value2, ppcost)
								end
								diag:hide()
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
			elseif mode == "sptoxp" then
				diag:Show({
					title = "Confirm Transaction",
					message = "Are you sure you want to convert " .. value1 .. " Spending Cash to " .. value2 .. " Experience Points?\nThis will use " .. ppcost .. "% of your Purchasing Power (PP).",
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
								if msim.settings.pp < ppcost then
									msim:error_message("You don't have enough Purchasing Power (PP)!")
								else
									msim:convert_currencies(mode, value1, value2, ppcost)
								end
								diag:hide()
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
		else msim:error_message("Invalid Conversion!") end
	end

	function msim:convert_currencies(mode, value1, value2, ppcost)
		if mode == "oftosp" then
			managers.money:_deduct_from_offshore(value1)
			managers.money:_add_to_total(value2, {no_offshore = true}, "msim")
		elseif mode == "sptocc" then
			managers.money:_deduct_from_total(value1)
			managers.custom_safehouse:add_coins(value2)
		elseif mode == "sptoxp" then
			managers.money:_deduct_from_total(value1)
			managers.experience:add_points(value2, false, true)
		end
		msim.settings.pp = msim.settings.pp - ppcost
		msim:save()
		msim:refresh()
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
		text = tostring(msim.settings.propsownedcount) .. "/" .. tostring(msim.settings.propsownedmax) .. " Owned",
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
			text = data.feature .. "\nby " .. data.feature_value,
			text_align = "left",
			size_by_text = true,
			lines = 3,
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
			text = data.feature .. "\nby " .. data.feature_value,
			text_align = "left",
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
		visible = "false",
		inherit_values = {
			offset = {0, 25}
		}
	})


	local oftospbox = self._menu:DivGroup({
		border_bottom = true,
		border_top = true,
		border_right = true,
		border_left = true,
		border_size = 2,
		align_method = "centered_grid",
		font_size = 25,
		max_height = 512,
		w = 1152,
		inherit_values = {
			size_by_text = true,
			font_size = 30,
			offset = {5, 0},
			align_method = "centered_grid"
		}
	})

	self.oftospslider1 = oftospbox:Slider({
		name = "Offshore Funds",
		min = 1,
		max = managers.money:offshore() * (msim.settings.pp / 100),
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.oftospslider2:SetValueByPercentage(self.oftospslider1.value / self.oftospslider1.max, false)
		end
	})

	local oftospimage1 = oftospbox:Image({
		texture = "textures/icons/offshore",
		w = 64,
		h = 64
	})

	local oftosparrow = oftospbox:Image({
		texture = "guis/textures/pd2/arrow_downcounter",
		w = 64,
		h = 64,
		icon_rotation = 90
	})

	local oftospimage2 = oftospbox:Image({
		texture = "guis/textures/pd2/blackmarket/cash_drop",
		w = 64,
		h = 64
	})

	local oftosprate = oftospbox:Divider({
		name = "oftosprate",
		text = " Conversion Rate: ".. msim.settings.oftsprate * 100 .. "%",
		position = "Left",
		offset = {10,10},
		w = 128,
		h = 64
	})

	local oftospbutton = oftospbox:ImageButton({
		name = "oftospbutton",
		texture = "textures/icons/convert",
		position = "Right",
		w = 128,
		h = 64,
		on_callback = function ()
			msim:confirm_convert_transac("oftosp", self.oftospslider1.value, self.oftospslider2.value, self.oftospslider1.value / self.oftospslider1.max * 100)
		end
	})

	self.oftospslider2 = oftospbox:Slider({
		name = "Spending Cash",
		min = 1,
		max = self.oftospslider1.max * msim.settings.oftsprate,
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.oftospslider1:SetValueByPercentage(self.oftospslider2.value / self.oftospslider2.max, false)
		end
	})

	local sptoccbox = self._menu:DivGroup({
		border_bottom = true,
		border_top = true,
		border_right = true,
		border_left = true,
		border_size = 2,
		align_method = "centered_grid",
		font_size = 25,
		max_height = 512,
		w = 1152,
		inherit_values = {
			size_by_text = true,
			font_size = 30,
			offset = {5, 0},
			align_method = "centered_grid"
		}
	})
	
	self.sptoccslider1 = sptoccbox:Slider({
		name = "Spending Cash",
		min = 1,
		max = managers.money:total() * (msim.settings.pp / 100),
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.sptoccslider2:SetValueByPercentage(self.sptoccslider1.value / self.sptoccslider1.max, false)
		end
	})
	
	local sptoccimage1 = sptoccbox:Image({
		texture = "guis/textures/pd2/blackmarket/cash_drop",
		w = 64,
		h = 64
	})
	
	local sptoccarrow = sptoccbox:Image({
		texture = "guis/textures/pd2/arrow_downcounter",
		w = 64,
		h = 64,
		icon_rotation = 90
	})
	
	local sptoccimage2 = sptoccbox:Image({
		texture = "guis/dlcs/chill/textures/pd2/safehouse/continental_coins_drop",
		w = 64,
		h = 64
	})

	local sptoccrate = sptoccbox:Divider({
		name = "sptoccrate",
		text = " Conversion Rate: ".. msim.settings.sptoccrate * 100 .. "%",
		position = "Left",
		offset = {10,10},
		w = 128,
		h = 64
	})
	
	local sptoccbutton = sptoccbox:ImageButton({
		name = "sptoccbutton",
		texture = "textures/icons/convert",
		position = "Right",
		w = 128,
		h = 64,
		on_callback = function ()
			msim:confirm_convert_transac("sptocc", self.sptoccslider1.value, self.sptoccslider2.value, self.sptoccslider1.value / self.sptoccslider1.max * 100)
		end
	})
	
	self.sptoccslider2 = sptoccbox:Slider({
		name = "Continental Coins",
		min = 1,
		max = self.sptoccslider1.max * msim.settings.sptoccrate,
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.sptoccslider1:SetValueByPercentage(self.sptoccslider2.value / self.sptoccslider2.max, false)
		end
	})

	local sptoxpbox = self._menu:DivGroup({
		border_bottom = true,
		border_top = true,
		border_right = true,
		border_left = true,
		border_size = 2,
		align_method = "centered_grid",
		font_size = 25,
		max_height = 512,
		w = 1152,
		inherit_values = {
			size_by_text = true,
			font_size = 30,
			offset = {5, 0},
			align_method = "centered_grid"
		}
	})
	
	self.sptoxpslider1 = sptoxpbox:Slider({
		name = "Spending Cash",
		min = 1,
		max = managers.money:total() * (msim.settings.pp / 100),
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.sptoxpslider2:SetValueByPercentage(self.sptoxpslider1.value / self.sptoxpslider1.max, false)
		end
	})
	
	local sptoxpimage1 = sptoxpbox:Image({
		texture = "guis/textures/pd2/blackmarket/cash_drop",
		w = 64,
		h = 64
	})
	
	local sptoxparrow = sptoxpbox:Image({
		texture = "guis/textures/pd2/arrow_downcounter",
		w = 64,
		h = 64,
		icon_rotation = 90
	})
	
	local sptoxpimage2 = sptoxpbox:Image({
		texture = "guis/textures/pd2/blackmarket/xp_drop",
		w = 64,
		h = 64
	})

	local sptoxprate = sptoxpbox:Divider({
		name = "sptoxprate",
		text = " Conversion Rate: ".. msim.settings.sptoxprate * 100 .. "%",
		position = "Left",
		offset = {10,10},
		w = 128,
		h = 64
	})
	
	local sptoxpbutton = sptoxpbox:ImageButton({
		name = "sptoxpbutton",
		texture = "textures/icons/convert",
		position = "Right",
		w = 128,
		h = 64,
		on_callback = function ()
			msim:confirm_convert_transac("sptoxp", self.sptoxpslider1.value, self.sptoxpslider2.value, self.sptoxpslider1.value / self.sptoxpslider1.max * 100)
		end
	})
	
	self.sptoxpslider2 = sptoxpbox:Slider({
		name = "Experience Points",
		min = 1,
		max = self.sptoxpslider1.max * msim.settings.sptoxprate,
		value = 1,
		floats = 0,
		wheel_control = true,
		on_callback = function ()
			self.sptoxpslider1:SetValueByPercentage(self.sptoxpslider2.value / self.sptoxpslider2.max, false)
		end
	})
end

MSIMInformationPage = MSIMInformationPage or class()

function MSIMInformationPage:make_stat(parent, name, value)
	local stattext = parent:DivGroup({
		name = "stattext",
		text = name
	})

	local stattoolbar = stattext:GetToolbar()
	local statcount = stattoolbar:Divider({
		name = "statcount",
		size_by_text = true,
		text = value,
		text_align = "right"
	})


end

function MSIMInformationPage:init(parent, navbar, pageholder)
	self._button = navbar:Button({
		name = "Information",
		text = "Information",
		border_size = 3,
		on_callback = ClassClbk(parent, "switch_pages", "info"),
		font_size = navbar_font_size
	})

	self._menu = pageholder:Menu({
		name = "infoholder",
		scrollbar = true,
		auto_height = true,
		visible = "false"
	})

	local statsheader = self._menu:DivGroup({
		name = "statsheader",
		text = "Statistics",
		--border_bottom = true,
		--border_size = 5,
		font_size = 35,
		offset = {0, 0},
		w = 400,
		background_color = BeardLib.Options:GetValue("MenuColor"):with_alpha(0.1),
		inherit_values = {
			background_color = BeardLib.Options:GetValue("MenuColor"):with_alpha(0.1),
			font_size = 25
		}
	})

	MSIMInformationPage:make_stat(statsheader, "Purchasing Power (PP)", msim.settings.pp .. "%")
	MSIMInformationPage:make_stat(statsheader, "Purchasing Power Recovery Rate (PPRR)", msim.settings.pprr .. "%")
	MSIMInformationPage:make_stat(statsheader, "Owned Properties", msim.settings.propsownedcount)
	MSIMInformationPage:make_stat(statsheader, "Maximum Owned Properties", msim.settings.propsownedmax)
	local totalvalue = 0
	for index, prop in ipairs(msim.settings.propsowned) do
		totalvalue = totalvalue + msim:get_actual_value(prop)
	end
	MSIMInformationPage:make_stat(statsheader, "Total Property Value", msim:make_money_string(totalvalue))
	MSIMInformationPage:make_stat(statsheader, "Property Discount", (1 - msim.settings.propdiscount) * 100 .. "%")
	MSIMInformationPage:make_stat(statsheader, "Offshore Funds to Spending Cash\nConversion Rate", msim.settings.oftsprate * 100 .. "%")
	MSIMInformationPage:make_stat(statsheader, "Spending Cash to Continental Coins\nConversion Rate", msim.settings.sptoccrate * 100 .. "%")
	MSIMInformationPage:make_stat(statsheader, "Spending Cash to Experience Points\nConversion Rate", msim.settings.sptoxprate * 100 .. "%")

	local guideheader = self._menu:DivGroup({
		name = "guideheader",
		text = "Guide",
		--border_bottom = true,
		--border_size = 5,
		font_size = 35,
		offset = {0, 0},
		w = 400,
		background_color = BeardLib.Options:GetValue("MenuColor"):with_alpha(0.1),
		inherit_values = {
			background_color = BeardLib.Options:GetValue("MenuColor"):with_alpha(0.1),
			font_size = 25
		}
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
		align_method = "grid",
		visible = "false"
	})
end

Hooks:PostHook(MissionEndState, 'at_enter', 'msim_getendstate',
function()
	msim:load()
	msim:pick_available_props(3)
	msim.settings.pp = math.min(msim.settings.pp + msim.settings.pprr, 100)
	msim:save()
end)