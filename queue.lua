local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
--local StorySoundService = require(ReplicatedStorage.Services.StorySoundService)

local placeId = 71861453126203

local Notify = ReplicatedStorage.Communication.Notification.Notify

local Zone = require(ReplicatedStorage.Classes.Zone)

local Lobby = {}
Lobby.__index = Lobby

function Lobby.new(model: Model)
	local self = setmetatable({}, Lobby)
	
	self.Model = model
	self.Capacity = model:GetAttribute("Capacity")
	self.Hardcore = model:GetAttribute("Hardcore")
	
	self.Zone = Zone.new(self.Model.Main)
	
	self.StartTime = model:GetAttribute("Time") or 30
	
	self.Time = self.StartTime
	self.Players = {}
	self.LastPlayers = {}
	
	self.AmountDisplay = model.Main.FSurface.Amount
	self.TypeDisplay = model.Main.FSurface.Type
	self.TimeDisplay = model.Main.FSurface.Time
	
	self.Info = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
	
	self.TypeDisplay.Text = "Story Mode"
	
	self:Update()
	
	self:SetUpConnections()
	
	task.spawn(function()
		self:Start()
	end)
	
	
	return self
end

local amount = 2

function Lobby:Start()
	while true do
		if #self.Players < amount then
			self.Time = 30
			self:Update()
		else
			self.Time -= 1
			self:Update()
			if self.Time <= 0 then
				self:Send()
				self:Reset()
				self:Update()
				task.wait(3)
			end
		end
		task.wait(1)
	end
end

function Lobby:Send()
	if #self.Players == 0 then return end
	return pcall(function()
		local options = Instance.new("TeleportOptions")
		local data = {
			Mode = self.Mode,
			Amount = #self.Players
		}
		options:SetTeleportData(data)
		options.ShouldReserveServer = true
		TeleportService:TeleportAsync(
			placeId,
			self.Players,
			options
		)
	end)
end

function Lobby:Reset()
	pcall(function()
		self.LastPlayers = self.Players
		table.clear(self.Players)
		self.Time = self.StartTime		
	end)

end

function Lobby:SetUpConnections()
	self.Connections = {}
	self.Connections.ZoneEntered = self.Zone.playerEntered:Connect(function(player)
		self:Entered(player)
		self:Update()
	end)
	self.Connections.ZoneExited = self.Zone.playerExited:Connect(function(player)
		self:Exited(player)
		self:Update()
	end)
	self.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:Exited(player)
	end)
end

function Lobby:Entered(player)
	if table.find(self.Players, player) ~= nil then return end --ensure that this player isn't already in the zone
	if #self.Players >= self.Capacity then 
		Notify:FireClient(player, {
			Title = "Queue Full",
			Text = "This queue is already full."
		})
		pcall(function()
			player.Character:PivotTo(self.Model:GetPivot():ToWorldSpace(CFrame.new(-10, 0, 0)))
		end)
		return
	end --ensure we not full out here
	if table.find(self.LastPlayers, player) then return end
	if self.Hardcore and player.leaderstats.Wins.Value == 0 then
		pcall(function()
			player.Character:PivotTo(self.Model:GetPivot():ToWorldSpace(CFrame.new(-10, 0, 0)))
		end)
		ReplicatedStorage.Communication.Hardcore.Display:FireClient(player, true)
		return
	end
	table.insert(self.Players, player)
	for index, currPlayer in self.Players do
		Notify:FireClient(currPlayer, {
			Title = "Player Joined",
			Text = player.Name .. " has joined the queue."
		})
	end
	--StorySoundService:Add3D("Enter", self.Model:GetChildren()[1], false, "Enter")
end

function Lobby:Exited(player)
	if table.find(self.Players, player) == nil then return end 
	if #self.Players <= 0 then return end
	for index, currPlayer in self.Players do
		Notify:FireClient(currPlayer, {
			Title = "Player Left",
			Text = player.Name .. " has left the queue."
		})
	end
	table.remove(self.Players, table.find(self.Players, player))
	--StorySoundService:Add3D("Exit", self.Model:GetChildren()[1], false, "Exit")
end

function Lobby:Update()
	pcall(function()
		if #self.Players < amount then
			self.AmountDisplay.Text = "Waiting for 2 players..."
		else
			self.AmountDisplay.Text = #self.Players .. "/" .. self.Capacity .. " Players"

		end
		self.TimeDisplay.Text = self.Time
		if #self.Players >= self.Capacity then
			self:Transition(true)
		else
			self:Transition(false)
		end		
	end)
end

function Lobby:Transition(green: boolean)
	for index, surface in self.Model.Main:GetChildren() do
		if not surface:IsA("SurfaceGui") then continue end
		TweenService:Create(
			surface.Aura,
			self.Info,
			{
				BackgroundColor3 = green and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
			}
		):Play()
	end
end

return Lobby