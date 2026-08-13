local GuiModule = {}

function GuiModule.create(context)
	context = context or {}
	local GuiRoot = context.GuiRoot
	local CoreGui = context.CoreGui or game:GetService("CoreGui")
	local UserInputService = context.UserInputService or game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local HttpService = game:GetService("HttpService")

	local Library = {
		Options = {},
		Toggles = {},
		ForceCheckbox = false,
		ShowToggleFrameInKeybinds = true,
		UnloadCallbacks = {},
		Unloaded = false,
	}

	local theme = {
		bg = Color3.fromRGB(18, 20, 24),
		panel = Color3.fromRGB(27, 30, 36),
		panel2 = Color3.fromRGB(34, 38, 45),
		tab = Color3.fromRGB(31, 35, 42),
		tabActive = Color3.fromRGB(42, 97, 177),
		text = Color3.fromRGB(238, 242, 247),
		muted = Color3.fromRGB(155, 165, 178),
		line = Color3.fromRGB(59, 67, 78),
		accent = Color3.fromRGB(66, 153, 225),
		success = Color3.fromRGB(72, 187, 120),
		danger = Color3.fromRGB(245, 101, 101),
	}

	local function make(className, props, children)
		local item = Instance.new(className)
		for key, value in pairs(props or {}) do
			item[key] = value
		end
		for _, child in ipairs(children or {}) do
			child.Parent = item
		end
		return item
	end

	local function corner(radius)
		return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
	end

	local function stroke(color, thickness)
		return make("UIStroke", {
			Color = color or theme.line,
			Thickness = thickness or 1,
		})
	end

	local function padding(px)
		return make("UIPadding", {
			PaddingTop = UDim.new(0, px),
			PaddingBottom = UDim.new(0, px),
			PaddingLeft = UDim.new(0, px),
			PaddingRight = UDim.new(0, px),
		})
	end

	local function list(spacing)
		return make("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, spacing or 8),
		})
	end

	local function safeCall(fn, ...)
		if type(fn) ~= "function" then
			return
		end
		local args = table.pack(...)
		task.spawn(function()
			local ok, err = pcall(fn, table.unpack(args, 1, args.n))
			if not ok then
				warn("[Mine a Mountain GUI] callback error:", err)
			end
		end)
	end

	local function optionChanged(key, value)
		if Library.Gui then
			pcall(function()
				Library.Gui:SetAttribute(key, value)
			end)
		end
	end

	function Library:Notify(message, duration)
		print("[Mine a Mountain]", message)

		local holder = self.NotifyHolder
		if not holder then
			return
		end

		local card = make("TextLabel", {
			BackgroundColor3 = theme.panel2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 42),
			Font = Enum.Font.Gotham,
			Text = tostring(message),
			TextColor3 = theme.text,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			corner(6),
			stroke(theme.line, 1),
			padding(10),
		})
		card.Parent = holder

		task.delay(tonumber(duration) or 3, function()
			if card.Parent then
				card:Destroy()
			end
		end)
	end

	function Library:OnUnload(callback)
		table.insert(self.UnloadCallbacks, callback)
	end

	function Library:Unload()
		if self.Unloaded then
			return
		end
		self.Unloaded = true

		for _, callback in ipairs(self.UnloadCallbacks) do
			local ok, err = pcall(callback)
			if not ok then
				warn("[Mine a Mountain GUI] unload error:", err)
			end
		end

		if self.Gui then
			self.Gui:Destroy()
			self.Gui = nil
		end
	end

	local function createLabel(parent, text, height, color)
		local label = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height or 24),
			Font = Enum.Font.Gotham,
			Text = tostring(text or ""),
			TextColor3 = color or theme.text,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		label.Parent = parent
		return label
	end

	local function makeControlObject(key, defaultValue, callback)
		local object = {
			Value = defaultValue,
			Callback = callback,
			Changed = Instance.new("BindableEvent"),
		}

		function object:OnChanged(fn)
			self.Changed.Event:Connect(fn)
		end

		function object:SetValue(value)
			if self.Value == value and type(value) ~= "table" then
				return
			end
			self.Value = value
			optionChanged(key, value)
			self.Changed:Fire(value)
			safeCall(self.Callback, value)
			if self.Render then
				self:Render()
			end
		end

		Library.Options[key] = object
		optionChanged(key, defaultValue)
		return object
	end

	function Library:CreateWindow(config)
		local guiName = "MineAMountainCustomGui"
		for _, container in ipairs({ GuiRoot, CoreGui }) do
			pcall(function()
				local old = container:FindFirstChild(guiName)
				if old then
					old:Destroy()
				end
			end)
		end

		local screenGui = make("ScreenGui", {
			Name = guiName,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		screenGui.Parent = GuiRoot
		self.Gui = screenGui

		local guiEvent = Instance.new("BindableEvent")
		guiEvent.Name = "GuiEvent"
		guiEvent.Parent = screenGui
		self.GuiEvent = guiEvent

		local root = make("Frame", {
			Name = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(760, 520),
			BackgroundColor3 = theme.bg,
			BorderSizePixel = 0,
		}, {
			corner(8),
			stroke(theme.line, 1),
		})
		root.Parent = screenGui
		self.Root = root

		local titleBar = make("Frame", {
			Name = "TitleBar",
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = theme.panel,
			BorderSizePixel = 0,
		}, {
			corner(8),
		})
		titleBar.Parent = root

		make("Frame", {
			Name = "TitleBottomFill",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = theme.panel,
			BorderSizePixel = 0,
		}).Parent = titleBar

		make("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = tostring(config and config.Title or "Window"),
			TextColor3 = theme.text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = titleBar

		make("TextLabel", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -52, 0, 0),
			Size = UDim2.fromOffset(180, 46),
			Font = Enum.Font.Gotham,
			Text = tostring(config and config.Footer or "Custom GUI"),
			TextColor3 = theme.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		}).Parent = titleBar

		local close = make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = theme.panel2,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "X",
			TextColor3 = theme.text,
			TextSize = 12,
			AutoButtonColor = false,
		}, {
			corner(6),
		})
		close.Parent = titleBar
		close.MouseButton1Click:Connect(function()
			screenGui.Enabled = false
		end)

		local body = make("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -46),
			BackgroundTransparency = 1,
		})
		body.Parent = root

		local sidebar = make("Frame", {
			Name = "Sidebar",
			Size = UDim2.new(0, 168, 1, 0),
			BackgroundColor3 = theme.panel,
			BorderSizePixel = 0,
		}, {
			padding(10),
			list(8),
		})
		sidebar.Parent = body

		local content = make("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(168, 0),
			Size = UDim2.new(1, -168, 1, 0),
			BackgroundColor3 = theme.bg,
			BorderSizePixel = 0,
		}, {
			padding(12),
		})
		content.Parent = body

		local notifyHolder = make("Frame", {
			Name = "Notifications",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 60),
			Size = UDim2.fromOffset(260, 280),
			BackgroundTransparency = 1,
		}, {
			list(8),
		})
		notifyHolder.Parent = screenGui
		self.NotifyHolder = notifyHolder

		local window = {
			Pages = {},
			Buttons = {},
			Sidebar = sidebar,
			Content = content,
		}

		local function setActive(name)
			for tabName, page in pairs(window.Pages) do
				page.Container.Visible = tabName == name
			end
			for tabName, button in pairs(window.Buttons) do
				button.BackgroundColor3 = tabName == name and theme.tabActive or theme.tab
			end
		end

		function window:AddTab(name, icon)
			local button = make("TextButton", {
				Name = name .. "TabButton",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = theme.tab,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = tostring(name),
				TextColor3 = theme.text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
			}, {
				corner(6),
				padding(10),
			})
			button.Parent = sidebar

			local pageFrame = make("Frame", {
				Name = name .. "Page",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = false,
			})
			pageFrame.Parent = content

			local left = make("ScrollingFrame", {
				Name = "Left",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(0.5, -6, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, {
				list(10),
			})
			left.Parent = pageFrame

			local right = make("ScrollingFrame", {
				Name = "Right",
				Position = UDim2.new(0.5, 6, 0, 0),
				Size = UDim2.new(0.5, -6, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, {
				list(10),
			})
			right.Parent = pageFrame

			local tab = {
				Name = name,
				Container = pageFrame,
				Left = left,
				Right = right,
			}

			local function addGroup(parent, titleText)
				local group = make("Frame", {
					Name = tostring(titleText):gsub("%s+", "") .. "Group",
					Size = UDim2.new(1, -4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = theme.panel,
					BorderSizePixel = 0,
				}, {
					corner(8),
					stroke(theme.line, 1),
					padding(12),
					list(8),
				})
				group.Parent = parent

				make("TextLabel", {
					Name = "Heading",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
					Font = Enum.Font.GothamBold,
					Text = tostring(titleText),
					TextColor3 = theme.text,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}).Parent = group

				local groupbox = { Frame = group }

				function groupbox:AddDivider()
					make("Frame", {
						Name = "Divider",
						Size = UDim2.new(1, 0, 0, 1),
						BackgroundColor3 = theme.line,
						BorderSizePixel = 0,
					}).Parent = group
				end

				function groupbox:AddLabel(text, wrap)
					local height = wrap and 42 or 24
					local label = createLabel(group, text, height, wrap and theme.muted or theme.text)
					local object = { Label = label, Value = text }

					function object:SetText(value)
						self.Value = value
						label.Text = tostring(value or "")
					end

					function object:AddKeyPicker(key, opts)
						local default = tostring((opts and opts.Default) or "F")
						local picker = makeControlObject(key, default, opts and opts.Callback)
						local row = make("TextButton", {
							Name = key,
							Size = UDim2.new(1, 0, 0, 34),
							BackgroundColor3 = theme.panel2,
							BorderSizePixel = 0,
							Font = Enum.Font.Gotham,
							Text = "",
							AutoButtonColor = false,
						}, {
							corner(6),
						})
						row.Parent = group

						local rowLabel = createLabel(row, tostring(opts and opts.Text or key), 34, theme.text)
						rowLabel.Position = UDim2.fromOffset(10, 0)
						rowLabel.Size = UDim2.new(1, -76, 1, 0)

						local keyText = make("TextLabel", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -10, 0.5, 0),
							Size = UDim2.fromOffset(58, 24),
							BackgroundColor3 = theme.tab,
							BorderSizePixel = 0,
							Font = Enum.Font.GothamBold,
							Text = default,
							TextColor3 = theme.text,
							TextSize = 12,
						}, {
							corner(5),
						})
						keyText.Parent = row

						local listening = false

						function picker:Render()
							keyText.Text = tostring(self.Value or "")
						end

						row.MouseButton1Click:Connect(function()
							listening = true
							keyText.Text = "..."
						end)

						UserInputService.InputBegan:Connect(function(input, processed)
							if processed or not listening then
								return
							end
							local name
							if input.UserInputType == Enum.UserInputType.Keyboard then
								name = input.KeyCode.Name
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
								name = "MB1"
							elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
								name = "MB2"
							elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
								name = "MB3"
							end
							if name then
								listening = false
								picker:SetValue(name)
							end
						end)

						picker:Render()
						return picker
					end

					return object
				end

				function groupbox:AddButton(text, callback)
					local button = make("TextButton", {
						Name = tostring(text):gsub("%s+", "") .. "Button",
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = theme.panel2,
						BorderSizePixel = 0,
						Font = Enum.Font.GothamBold,
						Text = tostring(text),
						TextColor3 = theme.text,
						TextSize = 13,
						AutoButtonColor = false,
					}, {
						corner(6),
					})
					button.Parent = group
					button.MouseButton1Click:Connect(function()
						safeCall(callback)
					end)
					return button
				end

				function groupbox:AddToggle(key, opts)
					local value = opts and opts.Default == true
					local object = makeControlObject(key, value, opts and opts.Callback)
					Library.Toggles[key] = object

					local row = make("TextButton", {
						Name = key,
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundColor3 = theme.panel2,
						BorderSizePixel = 0,
						Font = Enum.Font.Gotham,
						Text = "",
						AutoButtonColor = false,
					}, {
						corner(6),
					})
					row.Parent = group

					local label = createLabel(row, opts and opts.Text or key, 34, theme.text)
					label.Position = UDim2.fromOffset(10, 0)
					label.Size = UDim2.new(1, -58, 1, 0)

					local box = make("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(38, 20),
						BackgroundColor3 = value and theme.success or Color3.fromRGB(76, 83, 95),
						BorderSizePixel = 0,
					}, {
						corner(10),
					})
					box.Parent = row

					local knob = make("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderSizePixel = 0,
					}, {
						corner(8),
					})
					knob.Parent = box

					function object:Render()
						box.BackgroundColor3 = self.Value and theme.success or Color3.fromRGB(76, 83, 95)
						TweenService:Create(knob, TweenInfo.new(0.12), {
							Position = self.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
						}):Play()
					end

					row.MouseButton1Click:Connect(function()
						object:SetValue(not object.Value)
					end)

					object:Render()
					return object
				end

				function groupbox:AddInput(key, opts)
					local frame = make("Frame", {
						Name = key,
						Size = UDim2.new(1, 0, 0, 58),
						BackgroundTransparency = 1,
					})
					frame.Parent = group

					createLabel(frame, opts and opts.Text or key, 20, theme.text).Position = UDim2.fromOffset(0, 0)

					local default = tostring((opts and opts.Default) or "")
					local object = makeControlObject(key, default, opts and opts.Callback)

					local box = make("TextBox", {
						Position = UDim2.fromOffset(0, 24),
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundColor3 = theme.panel2,
						BorderSizePixel = 0,
						ClearTextOnFocus = false,
						Font = Enum.Font.Gotham,
						PlaceholderText = tostring((opts and opts.Placeholder) or ""),
						Text = default,
						TextColor3 = theme.text,
						PlaceholderColor3 = theme.muted,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, {
						corner(6),
						padding(10),
					})
					box.Parent = frame

					function object:Render()
						if box.Text ~= tostring(self.Value or "") then
							box.Text = tostring(self.Value or "")
						end
					end

					local changing = false
					box.FocusLost:Connect(function()
						object:SetValue(box.Text)
					end)
					if opts and opts.Finished == false then
						box:GetPropertyChangedSignal("Text"):Connect(function()
							if changing then
								return
							end
							changing = true
							object.Value = box.Text
							optionChanged(key, box.Text)
							safeCall(object.Callback, box.Text)
							changing = false
						end)
					end

					return object
				end

				function groupbox:AddSlider(key, opts)
					local minValue = tonumber(opts and opts.Min) or 0
					local maxValue = tonumber(opts and opts.Max) or 100
					local value = math.clamp(tonumber(opts and opts.Default) or minValue, minValue, maxValue)
					local object = makeControlObject(key, value, opts and opts.Callback)

					local frame = make("Frame", {
						Name = key,
						Size = UDim2.new(1, 0, 0, 58),
						BackgroundTransparency = 1,
					})
					frame.Parent = group

					local label = createLabel(frame, "", 20, theme.text)
					label.Position = UDim2.fromOffset(0, 0)

					local track = make("Frame", {
						Position = UDim2.fromOffset(0, 32),
						Size = UDim2.new(1, 0, 0, 10),
						BackgroundColor3 = theme.panel2,
						BorderSizePixel = 0,
					}, {
						corner(5),
					})
					track.Parent = frame

					local fill = make("Frame", {
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = theme.accent,
						BorderSizePixel = 0,
					}, {
						corner(5),
					})
					fill.Parent = track

					local knob = make("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(18, 18),
						BackgroundColor3 = theme.text,
						BorderSizePixel = 0,
					}, {
						corner(9),
					})
					knob.Parent = track

					local suffix = tostring((opts and opts.Suffix) or "")
					local dragging = false

					function object:Render()
						local alpha = 0
						if maxValue > minValue then
							alpha = (tonumber(self.Value) - minValue) / (maxValue - minValue)
						end
						alpha = math.clamp(alpha, 0, 1)
						fill.Size = UDim2.fromScale(alpha, 1)
						knob.Position = UDim2.fromScale(alpha, 0.5)
						label.Text = string.format("%s: %s%s", tostring(opts and opts.Text or key), tostring(self.Value), suffix)
					end

					local function setFromX(x)
						local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
						local raw = minValue + (maxValue - minValue) * alpha
						local rounding = tonumber(opts and opts.Rounding)
						if rounding and rounding > 0 then
							local scale = 10 ^ rounding
							raw = math.floor(raw * scale + 0.5) / scale
						else
							raw = math.floor(raw + 0.5)
						end
						object:SetValue(raw)
					end

					track.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = true
							setFromX(input.Position.X)
						end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							setFromX(input.Position.X)
						end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = false
						end
					end)

					object:Render()
					return object
				end

				function groupbox:AddDropdown(key, opts)
					local values = opts and opts.Values or {}
					local multi = opts and opts.Multi == true
					local default = multi and {} or nil
					local object = makeControlObject(key, default, opts and opts.Callback)
					object.Values = values
					object.Multi = multi

					local frame = make("Frame", {
						Name = key,
						Size = UDim2.new(1, 0, 0, multi and 0 or 60),
						AutomaticSize = multi and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
						BackgroundTransparency = 1,
					}, {
						list(6),
					})
					frame.Parent = group

					createLabel(frame, opts and opts.Text or key, 22, theme.text)

					local rows = {}

					local function rebuild()
						for _, row in ipairs(rows) do
							row:Destroy()
						end
						table.clear(rows)

						if multi then
							for _, valueName in ipairs(object.Values or {}) do
								local row = make("TextButton", {
									Name = tostring(valueName),
									Size = UDim2.new(1, 0, 0, 30),
									BackgroundColor3 = theme.panel2,
									BorderSizePixel = 0,
									Font = Enum.Font.Gotham,
									Text = "",
									AutoButtonColor = false,
								}, {
									corner(6),
								})
								row.Parent = frame
								rows[#rows + 1] = row

								local label = createLabel(row, tostring(valueName), 30, theme.text)
								label.Position = UDim2.fromOffset(10, 0)
								label.Size = UDim2.new(1, -58, 1, 0)

								local mark = make("TextLabel", {
									AnchorPoint = Vector2.new(1, 0.5),
									Position = UDim2.new(1, -10, 0.5, 0),
									Size = UDim2.fromOffset(28, 22),
									BackgroundColor3 = theme.tab,
									BorderSizePixel = 0,
									Font = Enum.Font.GothamBold,
									Text = "",
									TextColor3 = theme.text,
									TextSize = 12,
								}, {
									corner(5),
								})
								mark.Parent = row

								row.MouseButton1Click:Connect(function()
									local current = object.Value
									if type(current) ~= "table" then
										current = {}
									end
									current[valueName] = not current[valueName]
									object:SetValue(current)
									mark.Text = current[valueName] and "✓" or ""
								end)

								mark.Text = type(object.Value) == "table" and object.Value[valueName] and "✓" or ""
							end
							return
						end

						local button = make("TextButton", {
							Name = key .. "DropdownButton",
							Size = UDim2.new(1, 0, 0, 32),
							BackgroundColor3 = theme.panel2,
							BorderSizePixel = 0,
							Font = Enum.Font.Gotham,
							Text = object.Value and tostring(object.Value) or "None",
							TextColor3 = theme.text,
							TextSize = 13,
							AutoButtonColor = false,
						}, {
							corner(6),
						})
						button.Parent = frame
						rows[#rows + 1] = button

						button.MouseButton1Click:Connect(function()
							local listValues = object.Values or {}
							if #listValues == 0 then
								object:SetValue(nil)
								button.Text = "None"
								return
							end
							local index = table.find(listValues, object.Value) or 0
							index = index % #listValues + 1
							object:SetValue(listValues[index])
							button.Text = tostring(object.Value)
						end)
					end

					function object:SetValues(newValues)
						self.Values = newValues or {}
						rebuild()
					end

					function object:Render()
						for _, row in ipairs(rows) do
							if row:IsA("TextButton") and not multi then
								row.Text = self.Value and tostring(self.Value) or "None"
							end
						end
					end

					rebuild()
					return object
				end

				return groupbox
			end

			function tab:AddLeftGroupbox(titleText, icon)
				return addGroup(left, titleText)
			end

			function tab:AddRightGroupbox(titleText, icon)
				return addGroup(right, titleText)
			end

			window.Pages[name] = tab
			window.Buttons[name] = button
			button.MouseButton1Click:Connect(function()
				setActive(name)
			end)

			if not next(window.Pages) or not Library.ActiveTab then
				Library.ActiveTab = name
				setActive(name)
			end

			return tab
		end

		local dragging = false
		local dragStart
		local startPosition
		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPosition = root.Position
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = input.Position - dragStart
			root.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		UserInputService.InputBegan:Connect(function(input, processed)
			if processed or not screenGui.Parent then
				return
			end
			local picker = Library.ToggleKeybind
			local keyName = picker and picker.Value
			if input.UserInputType == Enum.UserInputType.Keyboard and keyName and input.KeyCode.Name == keyName then
				screenGui.Enabled = not screenGui.Enabled
			end
		end)

		if config and config.AutoShow == false then
			screenGui.Enabled = false
		end

		return window
	end

	local SaveManager = {
		Library = Library,
		Folder = "Universe",
		Configs = {},
		Autoload = "none",
		Ignore = {},
		DiskLoaded = false,
		MemoryOnlyWarned = false,
	}

	local function cloneForSave(value, depth)
		depth = depth or 0
		if depth > 8 then
			return nil
		end

		local valueType = type(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			return value
		end

		if valueType ~= "table" then
			return nil
		end

		local copy = {}
		for key, child in pairs(value) do
			local keyType = type(key)
			if keyType == "string" or keyType == "number" then
				local saved = cloneForSave(child, depth + 1)
				if saved ~= nil then
					copy[key] = saved
				end
			end
		end
		return copy
	end

	local function cleanPathPart(text)
		text = tostring(text or "")
		text = text:gsub("^%s+", ""):gsub("%s+$", "")

		local blocked = {
			[0] = true,
			[10] = true,
			[13] = true,
			[34] = true,
			[42] = true,
			[47] = true,
			[58] = true,
			[60] = true,
			[62] = true,
			[63] = true,
			[92] = true,
			[124] = true,
		}

		local out = {}
		for index = 1, #text do
			local byte = string.byte(text, index)
			out[#out + 1] = blocked[byte] and "_" or string.char(byte)
		end

		local cleaned = table.concat(out)
		if cleaned == "" then
			return nil
		end
		return cleaned
	end

	local function fileNameFromPath(filePath)
		filePath = tostring(filePath or "")
		local slash = filePath:match("^.*()/") or 0
		local backslash = filePath:match("^.*()\\") or 0
		local cut = math.max(slash, backslash)
		local name = cut > 0 and filePath:sub(cut + 1) or filePath
		return name:gsub("%.json$", "")
	end

	function SaveManager:CanUseFiles()
		return type(writefile) == "function"
			and type(readfile) == "function"
			and type(isfile) == "function"
			and type(isfolder) == "function"
			and type(makefolder) == "function"
	end

	function SaveManager:BasePath()
		return cleanPathPart(self.Folder) or "Universe"
	end

	function SaveManager:ConfigFolder()
		return self:BasePath() .. "/configs"
	end

	function SaveManager:ConfigPath(name)
		local cleanName = cleanPathPart(name)
		if not cleanName then
			return nil
		end
		return self:ConfigFolder() .. "/" .. cleanName .. ".json"
	end

	function SaveManager:AutoloadPath()
		return self:BasePath() .. "/autoload.txt"
	end

	function SaveManager:PrepareDisk()
		if not self:CanUseFiles() then
			return false, "local file API unavailable"
		end

		local ok, err = pcall(function()
			local base = self:BasePath()
			if not isfolder(base) then
				makefolder(base)
			end

			local configFolder = self:ConfigFolder()
			if not isfolder(configFolder) then
				makefolder(configFolder)
			end
		end)

		if not ok then
			return false, tostring(err)
		end

		return true
	end

	function SaveManager:WarnMemoryOnly(reason)
		if self.MemoryOnlyWarned then
			return
		end
		self.MemoryOnlyWarned = true
		if self.Library and self.Library.Notify then
			self.Library:Notify("Local file save unavailable; using memory only: " .. tostring(reason), 5)
		end
	end

	function SaveManager:ReadConfigFile(filePath, fallbackName)
		local ok, raw = pcall(readfile, filePath)
		if not ok or type(raw) ~= "string" then
			return nil, nil
		end

		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)

		if not decodedOk or type(decoded) ~= "table" then
			return nil, nil
		end

		local configName = decoded.name
		if type(configName) ~= "string" or configName == "" then
			configName = fallbackName
		end

		local values = decoded.values
		if type(values) ~= "table" then
			values = decoded
			values.name = nil
			values.savedAt = nil
		end

		return configName, values
	end

	function SaveManager:LoadDisk()
		local ready = self:PrepareDisk()
		if not ready then
			return false
		end

		if type(listfiles) == "function" then
			local ok, files = pcall(listfiles, self:ConfigFolder())
			if ok and type(files) == "table" then
				table.clear(self.Configs)
				for _, filePath in ipairs(files) do
					if tostring(filePath):sub(-5):lower() == ".json" then
						local fallbackName = fileNameFromPath(filePath)
						local name, values = self:ReadConfigFile(filePath, fallbackName)
						if type(name) == "string" and type(values) == "table" then
							self.Configs[name] = values
						end
					end
				end
			end
		end

		local autoloadPath = self:AutoloadPath()
		if isfile(autoloadPath) then
			local ok, value = pcall(readfile, autoloadPath)
			if ok and type(value) == "string" and value ~= "" then
				self.Autoload = value
			end
		end

		self.DiskLoaded = true
		return true
	end

	function SaveManager:SetLibrary(lib)
		self.Library = lib
	end

	function SaveManager:IgnoreThemeSettings()
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self.DiskLoaded = false
	end

	function SaveManager:SetIgnoreIndexes(list)
		table.clear(self.Ignore)
		for _, key in ipairs(list or {}) do
			self.Ignore[key] = true
		end
	end

	function SaveManager:RefreshConfigList()
		local ready, err = self:PrepareDisk()
		if ready then
			self:LoadDisk()
		else
			self:WarnMemoryOnly(err)
		end

		local names = {}
		for name in pairs(self.Configs) do
			names[#names + 1] = name
		end
		table.sort(names)
		return names
	end

	function SaveManager:Save(name)
		if type(name) ~= "string" or name:gsub("%s+", "") == "" then
			return false, "invalid name"
		end

		local data = {}
		for key, option in pairs(self.Library.Options) do
			if not self.Ignore[key] then
				local value = cloneForSave(option.Value)
				data[key] = value
			end
		end

		self.Configs[name] = data
		self.DiskLoaded = true

		local ready, err = self:PrepareDisk()
		if not ready then
			self:WarnMemoryOnly(err)
			return true
		end

		local filePath = self:ConfigPath(name)
		if not filePath then
			return false, "invalid name"
		end

		local encodedOk, encoded = pcall(function()
			return HttpService:JSONEncode({
				name = name,
				savedAt = os.time(),
				values = data,
			})
		end)

		if not encodedOk then
			return false, tostring(encoded)
		end

		local wrote, writeErr = pcall(writefile, filePath, encoded)
		if not wrote then
			return false, tostring(writeErr)
		end

		return true
	end

	function SaveManager:Load(name)
		if not self.DiskLoaded then
			self:LoadDisk()
		end

		local data = self.Configs[name]
		if not data then
			local ready = self:PrepareDisk()
			local filePath = ready and self:ConfigPath(name)
			if filePath and isfile(filePath) then
				local loadedName, loadedValues = self:ReadConfigFile(filePath, name)
				if loadedName and loadedValues then
					data = loadedValues
					self.Configs[loadedName] = loadedValues
				end
			end
		end

		if not data then
			return false, "config not found"
		end

		for key, value in pairs(data) do
			local option = self.Library.Options[key]
			if option and option.SetValue then
				option:SetValue(value)
			end
		end

		return true
	end

	function SaveManager:Delete(name)
		if not self.DiskLoaded then
			self:LoadDisk()
		end

		local existed = self.Configs[name] ~= nil
		self.Configs[name] = nil

		local ready = self:PrepareDisk()
		if ready then
			local filePath = self:ConfigPath(name)
			if filePath and isfile(filePath) then
				if type(delfile) == "function" then
					local deleted, deleteErr = pcall(delfile, filePath)
					if not deleted then
						return false, tostring(deleteErr)
					end
				else
					return false, "delfile unavailable"
				end
				existed = true
			end
		end

		if not existed then
			return false, "config not found"
		end

		if self.Autoload == name then
			self:DeleteAutoLoadConfig()
		end
		return true
	end

	function SaveManager:SaveAutoloadConfig(name)
		if type(name) ~= "string" or name == "" then
			return false, "invalid name"
		end
		self.Autoload = name

		local ready, err = self:PrepareDisk()
		if not ready then
			self:WarnMemoryOnly(err)
			return true
		end

		local wrote, writeErr = pcall(writefile, self:AutoloadPath(), name)
		if not wrote then
			return false, tostring(writeErr)
		end

		return true
	end

	function SaveManager:DeleteAutoLoadConfig()
		self.Autoload = "none"

		local ready = self:PrepareDisk()
		if ready and isfile(self:AutoloadPath()) and type(delfile) == "function" then
			pcall(delfile, self:AutoloadPath())
		end

		return true
	end

	function SaveManager:GetAutoloadConfig()
		if not self.DiskLoaded then
			self:LoadDisk()
		end
		return self.Autoload or "none"
	end

	function SaveManager:LoadAutoloadConfig()
		local autoload = self:GetAutoloadConfig()
		if autoload and autoload ~= "none" then
			return self:Load(autoload)
		end
		return true
	end

	local ThemeManager = {}

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
	end

	function ThemeManager:ApplyToTab(tab)
	end

	return Library, SaveManager, ThemeManager
end

return GuiModule
