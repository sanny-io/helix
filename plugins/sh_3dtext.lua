local PLUGIN = PLUGIN
PLUGIN.name = "3D Text"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds 3D text that can be placed anywhere."
PLUGIN.text = PLUGIN.text or {}

if (SERVER) then
	function PLUGIN:PlayerLoadedData(client)
		for k, v in ipairs(self.text) do
			netstream.Start(client, "nut_TextData", {v.pos, v.angle, v.text, v.scale})
		end
	end

	function PLUGIN:AddText(client, text, scale)
		local trace = client:GetEyeTraceNoCursor()
		local data = {
			pos = trace.HitPos + trace.HitNormal,
			angle = trace.HitNormal:Angle(),
			text = text,
			scale = math.max(math.abs(scale or 0.25), 0.25)
		}
		data.angle:RotateAroundAxis(data.angle:Up(), 90)
		data.angle:RotateAroundAxis(data.angle:Forward(), 90)

		self.text[#self.text + 1] = data

		netstream.Start(nil, "nut_TextData", {data.pos, data.angle, data.text, data.scale})
	end

	function PLUGIN:SaveData()
		nut.util.WriteTable("3dtext", self.text)
	end

	function PLUGIN:LoadData()
		self.text = nut.util.ReadTable("3dtext")
	end

	function PLUGIN:Remove(position, radius)
		local i = 0

		for k, v in ipairs(self.text) do
			if (v.pos:Distance(position) <= radius) then
				netstream.Start(nil, "nut_TextRemove", k)

				self.text[k] = nil
				i = i + 1
			end
		end

		return i
	end

	nut.command.Register({
		adminOnly = true,
		syntax = "<string text> [number scale]",
		onRun = function(client, arguments)
			if (!arguments[1] or string.len(arguments[1]) < 1) then
				nut.util.Notify(nut.lang.Get("missing_arg", 1), client)

				return
			end

			PLUGIN:AddText(client, arguments[1], tonumber(arguments[2]))
			nut.util.Notify("You have added 3D text to where you are aiming.", client)
		end
	}, "textadd")

	nut.command.Register({
		adminOnly = true,
		syntax = "[number radius]",
		onRun = function(client, arguments)
			local radius = tonumber(arguments[1]) or 256
			local count = PLUGIN:Remove(client:GetShootPos(), radius)

			nut.util.Notify("You have removed "..count.." 3D text(s).", client)
		end
	}, "textremove")
else
	netstream.Hook("nut_TextRemove", function(index)
		PLUGIN.text[index] = nil
	end)

	netstream.Hook("nut_TextData", function(data)
		local position = data[1]
		local angle = data[2]
		local text = data[3]
		local scale = data[4]

		scale = math.max(scale, 0.25)

		local markupText = "<font=nut_ScaledFont>"..string.gsub(text, "\\n", "\n")
		markupText = string.gsub(markupText, "\\t", "\t")
		markupText = markupText.."</font>"
		local markupObj = markup.Parse(markupText)
		PLUGIN.text[#PLUGIN.text + 1] = {pos = position, angle = angle, text = text, scale = scale, markup = markupObj}
	end)

	function PLUGIN:PostDrawTranslucentRenderables()
		local position = LocalPlayer():GetPos()

		for i = 1, #self.text do
			local data = self.text[i]

			if (data and position:Distance(data.pos) <= 1024) then
				cam.Start3D2D(data.pos, data.angle, data.scale or 0.25)
					data.markup:Draw(0, 0, 1, 1)
				cam.End3D2D()
			end
		end
	end
end