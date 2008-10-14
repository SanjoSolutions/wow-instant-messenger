-- imports
local WIM = WIM;
local _G = _G;
local pairs = pairs;
local string = string;
local table = table;
local time = time;

-- set namespace
setfenv(1, WIM);

local W2W = CreateModule("W2W", true);

db_defaults.w2w = {
    shareTyping = true,
    shareCoordinates = true,
};

local myServices = {};
local profileTip;

local Windows = windows.active.whisper;

local myTimer = _G.CreateFrame("Frame");
myTimer:Hide();

local function getW2WTable(win)
    if(not win.w2w) then
        win.w2w = {};
    end
    return win.w2w;
end

local function updateServices(user)
    for k, _ in pairs(myServices) do
        myServices[k] = nil;
    end
    -- add enabled services.
    if(db.w2w.shareTyping) then
        table.insert(myServices, "Typing");
    end
    if(db.w2w.shareCoordinates) then
        table.insert(myServices, "Coordinates");
    end
    
    table.sort(myServices);
end

local function getServicesStr(user)
    updateServices(user);
    return table.concat(myServices, ",");
end

local function SendServiceList(user)
    if(W2W.enabled) then
        SendData("WHISPER", user, "SERVICES", getServicesStr());
        if(Windows[user]) then
            getW2WTable(Windows[user]).sentServices = true;
        end
    end
end

local w2wWidgetCount = 1;
local function createWidget_W2W()
    local button = _G.CreateFrame("Button");
    button.flash = _G.CreateFrame("Frame", "W2W_Widget"..w2wWidgetCount, button);
    w2wWidgetCount = w2wWidgetCount + 1;
    button.flash:SetAllPoints();
    button.flash.bg = button.flash:CreateTexture(nil, "OVERLAY");
    button.flash.bg:SetAllPoints();
    button.SetActive = function(self, active)
            self.active = active;
            if(active) then
                self:Show();
                self.isFlashing = true;
                _G.UIFrameFlash(self.flash, .5, .5, 999999, nil, 0.5, 0.5);
            else
                self:Hide();
                if(self.isFlashing) then
                    self.isFlashing = false;
                    _G.UIFrameFlashStop(self.flash);
                end
            end
        end
    button.SetDefaults = function(self)
            self:SetActive(false);
        end
    button.SkinSet = function(self)
            self.flash.bg:SetTexture(GetSelectedSkin().message_window.widgets.w2w.HighlightTexture);
        end
    button:SetScript("OnEnter", function(self)
            if(self.active) then
                --ShowProfileTip(self, self.parentWindow.theUser, "TOPRIGHT", "TOPLEFT");
            end
        end);
    button:SetScript("OnLeave", function(self)
            if(profileTip) then
                profileTip:Hide();
            end
        end);
    
    return button;
end

local function createWidget_Chatting()
    local button = _G.CreateFrame("Button");
    button.SetActive = function(self, active)
            self.active = active;
            if(active) then
                self.lastActive = time();
                self:Show();
            else
                self.lastActive = 0;
                self:Hide();
            end
        end
    button.SetDefaults = function(self)
            self:SetActive(false);
        end
    button:SetScript("OnUpdate", function(self, elapsed)
            self.lastUpdate = self.lastUpdate + elapsed;
            while(self.lastUpdate > 2) do
                if(time() - getW2WTable(self.parentWindow).lastKeyPress > 5) then
                    self:SetActive(false);
                end
                self.lastUpdate = 0;
            end
        end);
    button:SetScript("OnEnter", function(self)
            if(self.active and db.showToolTips == true) then
		_G.GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
		    _G.GameTooltip:SetText(_G.format(L["%s is typing..."], self.parentWindow.theUser));
	    end
        end);
    button:SetScript("OnLeave", function(self) _G.GameTooltip:Hide(); end);
    button.lastUpdate = 0;
    return button;
end


function W2W:OnEnable()
    if(isPrivateServer) then
        -- Private servers can not handle AddonMessages
        W2W:Disable();
    else
        RegisterWidget("w2w", createWidget_W2W);
        RegisterWidget("chatting", createWidget_Chatting);
        for user, _ in pairs(Windows) do
            SendServiceList(user);
        end
        myTimer:Show();
        UpdateAllServices();
    end
end

function W2W:OnDisable()
    for widget in Widgets("w2w") do
        widget:SetActive(false); -- module is disabled, hide Icons.
    end
    for widget in Widgets("chatting") do
        widget:SetActive(false); -- module is disabled, hide Icons.
    end
    myTimer:Hide();
end

function W2W:OnWindowCreated(win)
    if(win.type == "whisper") then
        SendServiceList(win.theUser);
    end
end

function W2W:OnWindowDestroyed(win)
    -- clear any w2w data
    if(win.w2w) then
        for k, _ in pairs(win.w2w) do
            win.w2w[k] = nil;
        end
    end
end

local function getPositionStr()
	local C, Z, x, y = libs.Astrolabe:GetCurrentPlayerPosition();
	local zoneInfo, subZoneInfo;
	zoneInfo = _G.GetRealZoneText();
	subZoneInfo = _G.GetSubZoneText();
	if(not C) then C = 0; end
	if(not Z) then Z = 0; end
	if(not x) then x = 0; end
	if(not y) then y = 0; end
	if(subZoneInfo and subZoneInfo ~= zoneInfo and subZoneInfo ~= "") then zoneInfo = "("..zoneInfo..") ".._G.GetSubZoneText(); end
	return zoneInfo..":"..C..":"..Z..":"..x..":"..y;
end


-- w2w Profile tip
local function createProfileTip()
    local frame = _G.CreateFrame("Frame", "WIM3_ProfileTip", _G.UIParent);
    frame:Hide();
    frame:SetWidth(200); frame:SetHeight(300);
    frame:SetBackdrop({bgFile = "Interface\\AddOns\\"..addonTocName.."\\Modules\\Textures\\Menu_bg",
        edgeFile = "Interface\\AddOns\\"..addonTocName.."\\Modules\\Textures\\Menu", 
        tile = true, tileSize = 32, edgeSize = 32, 
        insets = { left = 32, right = 32, top = 32, bottom = 32 }});
    frame.title = frame:CreateFontString(nil, "OVERLAY", "ChatFontNormal");
    local font = frame.title:GetFont();
    frame.title:SetFont(font, 11, "");
    frame.title:SetPoint("TOPRIGHT", -20, -18);
    frame.title:SetText(L["W2W Profile"]);
    frame.title:SetJustifyV("TOP");
    frame.title:SetJustifyH("RIGHT");
    
    frame.pic = _G.CreateFrame("Frame", nil, frame);
    frame.pic:SetWidth(64); frame.pic:SetHeight(64);
    frame.pic:SetPoint("TOPLEFT", 20, -38);
    options.AddFramedBackdrop(frame.pic);
    frame.pic.backdrop.bg:SetTexture("Interface\\AddOns\\"..addonTocName.."\\Modules\\Textures\\avatar");
    frame.pic.backdrop.bg:SetAlpha(.75);
    
    frame.name = frame:CreateFontString(nil, "OVERLAY", "ChatFontNormal");
    local font = frame.name:GetFont();
    frame.name:SetFont(font, 18, "");
    frame.name:SetPoint("TOPLEFT", frame.pic, "TOPRIGHT", 5, 0);
    frame.name:SetText("Player Name");
    frame.name:SetJustifyV("TOP");
    frame.name:SetJustifyH("LEFT");
    
    
    frame:SetScript("OnShow", function(self)
            local width = 20+64+5+frame.name:GetStringWidth()+30;
            local height = 38+64+30;
            frame:SetWidth(width); frame:SetHeight(height);
            
        end);
    
    return frame;
end



function ShowProfileTip(frame, user, point, relativePoint)
    profileTip = profileTip or createProfileTip();
    profileTip:ClearAllPoints()
    profileTip:SetParent(frame);
    profileTip:SetPoint(point, frame, relativePoint, 0, 0);
    profileTip.name:SetText(user);
    profileTip.user = user;
    profileTip:Show();
end


-- typing
RegisterWidgetTrigger("msg_box", "whisper", "OnTextChanged", function(self)
        if(W2W.enabled and db.w2w.shareTyping) then
            if(string.trim(self:GetText()) == "") then
                getW2WTable(self.parentWindow).lastKeyPress = 0;
                SendData("WHISPER", self.parentWindow.theUser, "TYPING", 0);
            else
                if(time() - getW2WTable(self.parentWindow).lastKeyPress > 2) then
                    SendData("WHISPER", self.parentWindow.theUser, "TYPING", 1);
                    getW2WTable(self.parentWindow).lastKeyPress = time();
                end
            end
        end
    end);
RegisterWidgetTrigger("msg_box", "whisper", "OnShow", function(self) getW2WTable(self.parentWindow).lastKeyPress = 0; end);

RegisterAddonMessageHandler("TYPING", function(from, data)
        if(Windows[from] and Windows[from].widgets.chatting) then
            if(data == "1") then
                Windows[from].widgets.chatting:SetActive(true);
            else
                Windows[from].widgets.chatting:SetActive(false);
            end
        end
    end);
    


-- collect version from initial negotiation.
RegisterAddonMessageHandler("NEGOTIATE", function(from, data)
        if(Windows[from]) then
            getW2WTable(Windows[from]).version, getW2WTable(Windows[from]).isBeta = string.match(data, "^(.+):(%d)");
        end
    end);
    
-- Services
RegisterAddonMessageHandler("SERVICES", function(from, data)
        if(W2W.enabled and Windows[from]) then
            getW2WTable(Windows[from]).w2w = true;
            getW2WTable(Windows[from]).services = data;
            if( not Windows[from].online) then
                -- user has come back online... send services again.
                Windows[from].online = true;
                getW2WTable(Windows[from]).sentServices = nil;
            end
            if(W2W.enabled) then
                if(not getW2WTable(Windows[from]).sentServices) then
                    SendServiceList(from);
                end
                if(string.find(data, "Coordinates")) then
                    SendData("WHISPER", from, "GETLOC", "");
                end
                Windows[from].widgets.w2w:SetActive(true);
            end
        end
    end);
    
-- Location
RegisterAddonMessageHandler("LOC", function(from, data)
        if(Windows[from]) then
            local tbl = getW2WTable(Windows[from]);
            Windows[from].location, tbl.C, tbl.Z, tbl.x, tbl.y = string.match(data, "^(.+):(.+):(.+):(.+):(.+)$");
        end
    end);
RegisterAddonMessageHandler("GETLOC", function(from, data)
        if(W2W.enabled and db.w2w.shareCoordinates) then
            SendData("WHISPER", from, "LOC", getPositionStr());
        end
    end);
    

function UpdateAllServices()
    if(W2W.enabled) then
        for user, _  in pairs(Windows) do
            SendServiceList(user);
        end
    end
end

    
-- timer
myTimer.lastUpdate = 0;
myTimer:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed;
        while(self.lastUpdate > 5) do
            for user, win in pairs(Windows) do
                if(win.online and win.w2w and win.w2w.services) then
                    if(string.find(win.w2w.services, "Coordinates")) then
                        SendData("WHISPER", user, "GETLOC", "");
                    end
                end
            end
            self.lastUpdate = 0;
        end
    end);


