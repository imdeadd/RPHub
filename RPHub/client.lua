local QBCore = exports['qb-core']:GetCoreObject()

-- Client-side notification handler
RegisterNetEvent('rphub:notify')
AddEventHandler('rphub:notify', function(message, type)
    if type == 'success' then
        QBCore.Functions.Notify(message, 'success')
    elseif type == 'error' then
        QBCore.Functions.Notify(message, 'error')
    else
        QBCore.Functions.Notify(message, 'primary')
    end
end)

-- Optional: UI for rewards (if you want to show a menu)
RegisterCommand('shop', function()
    QBCore.Functions.Notify('Odwiedź nasz sklep: https://rphub.pl', 'info')
end, false)

print('^2[RPHub] Client script loaded^7')