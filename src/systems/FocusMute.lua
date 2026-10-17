local FocusMute = {}

FocusMute.focused = true

function FocusMute.enabled(settings)
    settings = settings or _G.gameSettings
    return not settings or settings.muteOnFocusLoss ~= false
end

function FocusMute.apply(settings)
    local a = _G.audioSystem
    if not a or not a.setFocused then return end
    a:setFocused(FocusMute.focused or not FocusMute.enabled(settings))
end

function FocusMute.onFocus(focused)
    FocusMute.focused = focused and true or false
    FocusMute.apply()
end

return FocusMute
