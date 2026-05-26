FasterCurrencyDeposits = FasterCurrencyDeposits or {}
FasterCurrencyDeposits.name = "FasterCurrencyDeposits"
FasterCurrencyDeposits.version = "1.0.2"
FasterCurrencyDeposits.buttonCreated = false

local supportedCurrencies = {
	{
		key = "gold",
		name = "Gold",
		currencyType = CURT_MONEY,
	},
	{
		key = "telvar",
		name = "Tel Var Stones",
		currencyType = CURT_TELVAR_STONES,
	},
	{
		key = "alliance",
		name = "Alliance Points",
		currencyType = CURT_ALLIANCE_POINTS,
	},
	{
		key = "writ",
		name = "Writ Vouchers",
		currencyType = CURT_WRIT_VOUCHERS,
	},
}

local defaults = {
	enabled = true,
	autoDeposit = false,
	debug = false,
	showSummary = false,

	depositCurrencies = {
		gold = true,
		telvar = false,
		alliance = false,
		writ = false,
	},
	withholdAmounts = {
		gold = "0",
		telvar = "0",
		alliance = "0",
		writ = "0",
	},
}

function FasterCurrencyDeposits:Debug(message)
	if self.savedVars.debug then
		d("[Faster Currency] " .. tostring(message))
	end
end

function FasterCurrencyDeposits:DepositCurrency(currencyType, currencyName, withholdAmount)
	local amount = GetCarriedCurrencyAmount(currencyType)

	if amount and amount > 0 then
		local depositAmount = amount - withholdAmount

		if depositAmount <= 0 then
			self:Debug("Skipping " .. tostring(currencyName) .. " (Inventory within withhold threshold).")
			return nil
		end

		DepositCurrencyIntoBank(currencyType, depositAmount)

		self:Debug("Deposited " .. tostring(depositAmount) .. " " .. tostring(currencyName))

		return {
			amount = depositAmount,
			currencyType = currencyType,
			currencyName = currencyName,
		}
	end

	self:Debug("No " .. tostring(currencyName) .. " available.")

	return nil
end

function FasterCurrencyDeposits:PrintDepositSummary(results)
	if not self.savedVars.showSummary then
		return
	end

	if #results <= 0 then
		return
	end

	d("|cD5B76A Deposited:")

	for _, result in ipairs(results) do
		local formattedAmount = ZO_CommaDelimitNumber(result.amount)
		local icon = zo_iconFormat(GetCurrencyKeyboardIcon(result.currencyType), 20, 20)
		d(string.format(" • %s %s %s", icon, formattedAmount, result.currencyName))
	end
end

function FasterCurrencyDeposits:ExecuteDeposits()
	if not self.savedVars.enabled then
		return
	end

	local depositedResults = {}
	for _, currencyData in ipairs(supportedCurrencies) do
		local enabled = self.savedVars.depositCurrencies[currencyData.key]
		if enabled then
			local withhold = tonumber(self.savedVars.withholdAmounts[currencyData.key]) or 0
			local result = self:DepositCurrency(currencyData.currencyType, currencyData.name, withhold)
			if result then
				table.insert(depositedResults, result)
			end
		end
	end

	if #depositedResults <= 0 then
		self:Debug("Nothing to deposit.")
		return
	end

	self:PrintDepositSummary(depositedResults)

	zo_callLater(function()
		if BANKCurrencyTransferDialogCancel then
			BANKCurrencyTransferDialogCancel:OnClicked()
			FasterCurrencyDeposits:Debug("Triggered cancel button.")
		end
	end, 50)
end

function FasterCurrencyDeposits:GetDepositButtonText()
	local selected = {}

	for _, currencyData in ipairs(supportedCurrencies) do
		if self.savedVars.depositCurrencies[currencyData.key] then
			table.insert(selected, currencyData.name)
		end
	end

	if #selected == 0 then
		return "Deposit Currencies"
	elseif #selected == 1 then
		return "Deposit " .. selected[1]
	elseif #selected == #supportedCurrencies then
		return "Deposit Currencies"
	else
		return "Deposit Selected"
	end
end

function FasterCurrencyDeposits:UpdateButtonText()
	if not self.buttonLabel then
		return
	end

	self.buttonLabel:SetText(self:GetDepositButtonText())
end

function FasterCurrencyDeposits:CreateButton()
	if self.buttonCreated then
		return
	end

	local button = WINDOW_MANAGER:CreateControl("FasterCurrencyDepositsButton", BANKCurrencyTransferDialog, CT_BUTTON)
	button:SetDimensions(220, 28)
	button:SetAnchor(TOP, BANKCurrencyTransferDialogContainerDepositWithdrawCurrency, BOTTOM, 0, 24)

	local label = WINDOW_MANAGER:CreateControl(nil, button, CT_LABEL)
	label:SetAnchor(CENTER, button, CENTER, 0, 0)
	label:SetFont("ZoFontWinH3")
	label:SetColor(0.886, 0.839, 0.639, 1)
	label:SetText("Deposit Currencies")

	local glow = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
	glow:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_left_right.dds")
	glow:SetBlendMode(TEX_BLEND_MODE_ADD)
	glow:SetAnchor(CENTER, label, CENTER, 0, 0)
	glow:SetDimensions(220, 40)
	glow:SetAlpha(0)
	glow:SetDrawLayer(DL_BACKGROUND)

	button:SetHandler("OnMouseEnter", function()
		glow:SetAlpha(0.25)
		label:SetColor(1, 0.95, 0.75, 1)
		PlaySound(SOUNDS.DEFAULT_CLICK)
	end)

	button:SetHandler("OnMouseExit", function()
		glow:SetAlpha(0)
		label:SetColor(0.886, 0.839, 0.639, 1)
	end)

	button:SetHandler("OnClicked", function()
		FasterCurrencyDeposits:ExecuteDeposits()
	end)
	button:SetHidden(true)

	self.button = button
	self.buttonLabel = label
	self:UpdateButtonText()
	self.buttonCreated = true

	self:Debug("ESO-style button created.")
end

function FasterCurrencyDeposits:IsDepositMode()
	local titleText = BANKCurrencyTransferDialogTitle:GetText()
	if not titleText then
		return false
	end

	return string.find(string.upper(titleText), "DEPOSIT") ~= nil
end

function FasterCurrencyDeposits.OnDialogShown()
	if not FasterCurrencyDeposits.savedVars.enabled then
		if FasterCurrencyDeposits.button then
			FasterCurrencyDeposits.button:SetHidden(true)
		end

		FasterCurrencyDeposits:Debug("Addon disabled.")
		return
	end

	if not FasterCurrencyDeposits.buttonCreated then
		FasterCurrencyDeposits:CreateButton()
	end

	if FasterCurrencyDeposits:IsDepositMode() then
		FasterCurrencyDeposits.button:SetHidden(false)

		FasterCurrencyDeposits:Debug("Deposit mode detected.")

		if FasterCurrencyDeposits.savedVars.autoDeposit then
			zo_callLater(function()
				FasterCurrencyDeposits:ExecuteDeposits()
			end, 100)
		end
	else
		FasterCurrencyDeposits.button:SetHidden(true)

		FasterCurrencyDeposits:Debug("Withdraw mode detected.")
	end
end

function FasterCurrencyDeposits.OnDialogHidden()
	if FasterCurrencyDeposits.button then
		FasterCurrencyDeposits.button:SetHidden(true)
	end
end

function FasterCurrencyDeposits:CreateSettingsMenu()
	local LAM2 = LibAddonMenu2
	if not LAM2 then
		d("[Faster Currency] LibAddonMenu-2.0 missing.")
		return
	end

	local panelData = {
		type = "panel",
		name = "Faster Currency Deposits",
		displayName = "Faster Currency Deposits",
		author = "Revel",
		version = self.version,
		registerForRefresh = true,
		registerForDefaults = true,
	}

	LAM2:RegisterAddonPanel("FasterCurrencyDepositsOptions", panelData)

	local function IsAddonDisabled()
		return not self.savedVars.enabled
	end

	local optionsTable = {
		{
			type = "checkbox",
			name = "Enable Addon",
			default = defaults.enabled,
			getFunc = function()
				return self.savedVars.enabled
			end,
			setFunc = function(value)
				self.savedVars.enabled = value
			end,
		},
		{
			type = "checkbox",
			name = "Auto Deposit",
			disabled = IsAddonDisabled,
			tooltip = "Automatically deposits selected currencies.",
			default = defaults.autoDeposit,
			getFunc = function()
				return self.savedVars.autoDeposit
			end,
			setFunc = function(value)
				self.savedVars.autoDeposit = value
			end,
		},
		{
			type = "checkbox",
			name = "Show Deposit Summary",
			disabled = IsAddonDisabled,
			tooltip = "Displays a chat summary of deposited currencies.",
			default = defaults.showSummary,
			getFunc = function()
				return self.savedVars.showSummary
			end,
			setFunc = function(value)
				self.savedVars.showSummary = value
			end,
		},
		{
			type = "header",
			name = "Currencies",
		},
		{
			type = "checkbox",
			name = "Deposit Gold",
			disabled = IsAddonDisabled,
			default = defaults.depositCurrencies.gold,
			getFunc = function()
				return self.savedVars.depositCurrencies.gold
			end,
			setFunc = function(value)
				self.savedVars.depositCurrencies.gold = value
				self:UpdateButtonText()
			end,
		},
		{
			type = "checkbox",
			name = "Deposit Tel Var Stones",
			disabled = IsAddonDisabled,
			default = defaults.depositCurrencies.telvar,
			getFunc = function()
				return self.savedVars.depositCurrencies.telvar
			end,
			setFunc = function(value)
				self.savedVars.depositCurrencies.telvar = value
				self:UpdateButtonText()
			end,
		},
		{
			type = "checkbox",
			name = "Deposit Alliance Points",
			disabled = IsAddonDisabled,
			default = defaults.depositCurrencies.alliance,
			getFunc = function()
				return self.savedVars.depositCurrencies.alliance
			end,
			setFunc = function(value)
				self.savedVars.depositCurrencies.alliance = value
				self:UpdateButtonText()
			end,
		},
		{
			type = "checkbox",
			name = "Deposit Writ Vouchers",
			disabled = IsAddonDisabled,
			default = defaults.depositCurrencies.writ,
			getFunc = function()
				return self.savedVars.depositCurrencies.writ
			end,
			setFunc = function(value)
				self.savedVars.depositCurrencies.writ = value
				self:UpdateButtonText()
			end,
		},
		{
			type = "header",
			name = "Minimum Inventory Reserves",
		},
		{
			type = "description",
			text = "Specify the minimum amount of currency to keep in your inventory.",
		},
		{
			type = "editbox",
			name = "Gold to Withhold",
			disabled = IsAddonDisabled,
			isNumeric = true,
			default = defaults.withholdAmounts.gold,
			getFunc = function()
				return self.savedVars.withholdAmounts.gold
			end,
			setFunc = function(value)
				self.savedVars.withholdAmounts.gold = value
			end,
		},
		{
			type = "editbox",
			name = "Tel Var Stones to Withhold",
			disabled = IsAddonDisabled,
			isNumeric = true,
			default = defaults.withholdAmounts.telvar,
			getFunc = function()
				return self.savedVars.withholdAmounts.telvar
			end,
			setFunc = function(value)
				self.savedVars.withholdAmounts.telvar = value
			end,
		},
		{
			type = "editbox",
			name = "Alliance Points to Withhold",
			disabled = IsAddonDisabled,
			isNumeric = true,
			default = defaults.withholdAmounts.alliance,
			getFunc = function()
				return self.savedVars.withholdAmounts.alliance
			end,
			setFunc = function(value)
				self.savedVars.withholdAmounts.alliance = value
			end,
		},
		{
			type = "editbox",
			name = "Writ Vouchers to Withhold",
			disabled = IsAddonDisabled,
			isNumeric = true,
			default = defaults.withholdAmounts.writ,
			getFunc = function()
				return self.savedVars.withholdAmounts.writ
			end,
			setFunc = function(value)
				self.savedVars.withholdAmounts.writ = value
			end,
		},
		{
			type = "header",
			name = "Debug",
		},
		{
			type = "checkbox",
			name = "Enable Debug Logging",
			default = defaults.debug,
			getFunc = function()
				return self.savedVars.debug
			end,
			setFunc = function(value)
				self.savedVars.debug = value
			end,
		},
	}

	LAM2:RegisterOptionControls("FasterCurrencyDepositsOptions", optionsTable)
end

function FasterCurrencyDeposits.OnAddonLoaded(eventCode, addonName)
	if addonName ~= FasterCurrencyDeposits.name then
		return
	end

	EVENT_MANAGER:UnregisterForEvent(FasterCurrencyDeposits.name, EVENT_ADD_ON_LOADED)

	FasterCurrencyDeposits.savedVars = ZO_SavedVars:NewAccountWide("FasterCurrencyDeposits_SV", 1, nil, defaults)

	ZO_PreHookHandler(BANKCurrencyTransferDialog, "OnEffectivelyShown", FasterCurrencyDeposits.OnDialogShown)
	ZO_PreHookHandler(BANKCurrencyTransferDialog, "OnEffectivelyHidden", FasterCurrencyDeposits.OnDialogHidden)

	FasterCurrencyDeposits:CreateSettingsMenu()

	FasterCurrencyDeposits:Debug("[Faster Currency Deposits] Loaded.")
end

EVENT_MANAGER:RegisterForEvent(FasterCurrencyDeposits.name, EVENT_ADD_ON_LOADED, FasterCurrencyDeposits.OnAddonLoaded)
