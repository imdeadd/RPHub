local QBCore = exports['qb-core']:GetCoreObject()
local cooldowns = {}
local isVerified = false
local API_KEY = Config.APIKey
local SERVER_IP = nil
local BACKEND_URL = 'http://62.133.157.125:4000'

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

CreateThread(function()
    MySQL.query.await('CREATE TABLE IF NOT EXISTS RPHub_rewards (id INT AUTO_INCREMENT PRIMARY KEY, citizenid VARCHAR(50), item VARCHAR(50), amount INT, status VARCHAR(20), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)')
    print('^2[RPHub] Database initialized^7')
    
    Wait(2000)
    if not SERVER_IP and Config.ServerIP then
        SERVER_IP = Config.ServerIP
        print('^2[RPHub] Użyto ręcznie ustawionego IP: ' .. SERVER_IP .. '^7')
    elseif not SERVER_IP then
        PerformHttpRequest('https://api.ipify.org', function(err, text, headers)
            if err == 200 and text then
                SERVER_IP = text .. ':30120'
                print('^2[RPHub] Automatycznie wykryto IP: ' .. SERVER_IP .. '^7')
            else
                SERVER_IP = '127.0.0.1:30120'
                print('^1[RPHub] Nie udało się wykryć IP, używam domyślnego: ' .. SERVER_IP .. '^7')
            end
        end)
    end
end)

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
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.steam == identifier or player.PlayerData.citizenid == identifier or string.lower(player.PlayerData.name) == string.lower(identifier) then
            return player
        end
    end
    return nil
end

function GiveReward(source, rewardData)
    if not isVerified then
        print('^1[RPHub] Klucz API niezweryfikowany, odrzucam nagrodę^7')
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local citizenid = Player.PlayerData.citizenid
    
    if cooldowns[citizenid] and (os.time() - cooldowns[citizenid]) < Config.Cooldown then
        TriggerClientEvent('ox_lib:notify', source, {title = 'RPHub', description = 'Proszę zaczekaj przed odebraniem kolejnej nagrody', type = 'error'})
        return false
    end
    
    if rewardData.fivemMoneyAmount and rewardData.fivemMoneyAmount > 0 then
        Player.Functions.AddMoney('cash', rewardData.fivemMoneyAmount)
        TriggerClientEvent('ox_lib:notify', source, {title = 'RPHub', description = string.format('Otrzymałeś $%d', rewardData.fivemMoneyAmount), type = 'success'})
    end
    
    if rewardData.fivemItem and rewardData.fivemItemAmount then
        Player.Functions.AddItem(rewardData.fivemItem, rewardData.fivemItemAmount)
        TriggerClientEvent('ox_lib:notify', source, {title = 'RPHub', description = string.format('Otrzymałeś %dx %s', rewardData.fivemItemAmount, rewardData.fivemItem), type = 'success'})
    end
    
    if rewardData.fivemJob then
        local jobData = QBShared.Jobs[rewardData.fivemJob]
        if jobData then
            Player.Functions.SetJob(rewardData.fivemJob, 0)
            TriggerClientEvent('ox_lib:notify', source, {title = 'RPHub', description = string.format('Twoja praca została zmieniona na %s', jobData.label), type = 'success'})
        end
    end
    
    cooldowns[citizenid] = os.time()
    
    MySQL.query('INSERT INTO RPHub_rewards (citizenid, item, amount, status) VALUES (?, ?, ?, ?)', {
        citizenid,
        rewardData.fivemItem or 'money',
        rewardData.fivemItemAmount or rewardData.fivemMoneyAmount or 0,
        'delivered'
    })
    
    return true
end

RegisterNetEvent('RPHub:giveReward')
AddEventHandler('RPHub:giveReward', function(data)
    local src = source
    GiveReward(src, data.rewardData)
end)

RegisterNetEvent('RPHub:giveRewardByIdentifier')
AddEventHandler('RPHub:giveRewardByIdentifier', function(data)
    if not isVerified then
        print('^1[RPHub] Klucz API niezweryfikowany^7')
        return
    end
    local target = GetPlayerByIdentifier(data.identifier)
    if target then
        GiveReward(target.PlayerData.source, data.rewardData)
    end
end)

RegisterCommand('testreward', function(source, args)
    local reward = {
        fivemMoneyAmount = 1000,
        fivemItem = 'bread',
        fivemItemAmount = 5
    }
    GiveReward(source, reward)
end, false)

exports('GiveReward', GiveReward)
exports('GetPlayerByIdentifier', GetPlayerByIdentifier)
exports('IsVerified', function() return isVerified end)

print('^2[RPHub] FiveM script loaded successfully^7')