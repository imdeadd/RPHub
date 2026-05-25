local ESX = nil
local cooldowns = {}
local isVerified = false
local API_KEY = Config.APIKey
local SERVER_IP = Config.ServerIP
local BACKEND_URL = 'http://62.133.157.125:4000'

CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end
    
    MySQL.query.await('CREATE TABLE IF NOT EXISTS RPHub_rewards (id INT AUTO_INCREMENT PRIMARY KEY, identifier VARCHAR(50), item VARCHAR(50), amount INT, status VARCHAR(20), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)')
    print('^2[RPHub ESX] Database initialized^7')
    
    if not SERVER_IP then
        PerformHttpRequest('https://api.ipify.org', function(err, text, headers)
            if err == 200 and text then
                SERVER_IP = text .. ':30120'
                print('^2[RPHub] Automatycznie wykryto IP: ' .. SERVER_IP .. '^7')
            else
                SERVER_IP = '127.0.0.1:30120'
                print('^1[RPHub] Nie udało się wykryć IP, używam domyślnego: ' .. SERVER_IP .. '^7')
            end
        end)
    else
        print('^2[RPHub] Użyto ręcznie ustawionego IP: ' .. SERVER_IP .. '^7')
    end
end)

function GetPublicIP()
    local result = nil
    PerformHttpRequest('https://api.ipify.org', function(err, text, headers)
        if err == 200 and text then
            result = text
            print('^2[RPHub] Publiczne IP serwera: ' .. result .. '^7')
        else
            print('^1[RPHub] Nie udało się pobrać publicznego IP^7')
        end
    end)
    return result
end

function VerifyApiKey()
    if not SERVER_IP then
        print('^1[RPHub] Oczekiwanie na wykrycie IP...^7')
        return
    end
    
    local url = BACKEND_URL .. '/api/verify-key/fivem'
    local data = {
        apiKey = API_KEY,
        serverIp = SERVER_IP
    }
    
    print('^2[RPHub] ========== WERYFIKACJA KLUCZA API ==========^7')
    print('^2[RPHub] URL: ' .. url)
    print('^2[RPHub] API Key: ' .. string.sub(API_KEY, 1, 10) .. '...')
    print('^2[RPHub] Server IP: ' .. SERVER_IP)
    
    PerformHttpRequest(url, function(err, text, headers)
        if err == 200 then
            local result = json.decode(text)
            if result and result.valid then
                isVerified = true
                print('^2[RPHub] ✅ Klucz API zweryfikowany pomyślnie!^7')
                print('^2[RPHub] Serwer: ' .. (result.serverName or 'nieznany') .. '^7')
            else
                isVerified = false
                print('^1[RPHub] ❌ Błąd weryfikacji: ' .. (result and result.error or 'Nieznany błąd') .. '^7')
            end
        elseif err == 401 then
            isVerified = false
            print('^1[RPHub] ❌ BŁĄD 401 - Nieprawidłowy klucz API!^7')
        else
            isVerified = false
            print('^1[RPHub] ❌ Nie udało się połączyć (HTTP ' .. err .. ')^7')
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json',
        ['x-api-key'] = API_KEY
    })
end

CreateThread(function()
    Wait(5000)
    VerifyApiKey()
    
    while true do
        Wait(400000)
        if not isVerified then
            VerifyApiKey()
        end
    end
end)

function GetPlayerByIdentifier(identifier)
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            if xPlayer.identifier == identifier or string.lower(xPlayer.getName()) == string.lower(identifier) then
                return xPlayer
            end
        end
    end
    return nil
end

function GiveReward(player, rewardData)
    if not isVerified then
        print('^1[RPHub] Klucz API niezweryfikowany, odrzucam nagrodę^7')
        return false
    end
    
    if not player then return false end
    
    local identifier = player.identifier
    
    if cooldowns[identifier] and (os.time() - cooldowns[identifier]) < Config.Cooldown then
        player.showNotification('Proszę zaczekaj przed odebraniem kolejnej nagrody', 'error')
        return false
    end
    
    if rewardData.fivemMoneyAmount and rewardData.fivemMoneyAmount > 0 then
        player.addMoney(rewardData.fivemMoneyAmount)
        player.showNotification(string.format('Otrzymałeś $%d', rewardData.fivemMoneyAmount), 'success')
    end
    
    if rewardData.fivemItem and rewardData.fivemItemAmount then
        if rewardData.fivemItemAmount > 0 then
            player.addInventoryItem(rewardData.fivemItem, rewardData.fivemItemAmount)
            player.showNotification(string.format('Otrzymałeś %dx %s', rewardData.fivemItemAmount, rewardData.fivemItem), 'success')
        end
    end
    
    if rewardData.fivemJob then
        player.setJob(rewardData.fivemJob, 0)
        player.showNotification(string.format('Twoja praca została zmieniona na %s', rewardData.fivemJob), 'success')
    end
    
    cooldowns[identifier] = os.time()
    
    MySQL.query('INSERT INTO RPHub_rewards (identifier, item, amount, status) VALUES (?, ?, ?, ?)', {
        identifier,
        rewardData.fivemItem or 'money',
        rewardData.fivemItemAmount or rewardData.fivemMoneyAmount or 0,
        'delivered'
    })
    
    return true
end

RegisterNetEvent('RPHub:giveReward')
AddEventHandler('RPHub:giveReward', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        GiveReward(xPlayer, data.rewardData)
    end
end)

RegisterNetEvent('RPHub:giveRewardByIdentifier')
AddEventHandler('RPHub:giveRewardByIdentifier', function(data)
    if not isVerified then
        print('^1[RPHub] Klucz API niezweryfikowany^7')
        return
    end
    local target = GetPlayerByIdentifier(data.identifier)
    if target then
        GiveReward(target, data.rewardData)
    end
end)

ESX.RegisterCommand('testreward', 'admin', function(xPlayer, args, showError)
    local reward = {
        fivemMoneyAmount = 1000,
        fivemItem = 'bread',
        fivemItemAmount = 5
    }
    GiveReward(xPlayer, reward)
end, false, { help = 'Test nagrody RPHub' })

exports('GiveReward', GiveReward)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('IsVerified', function() return isVerified end)

print('^2[RPHub ESX] Script loaded successfully^7')