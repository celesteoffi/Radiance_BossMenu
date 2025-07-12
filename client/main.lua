--============================================================--
--  Boss-Menu – CLIENT v3.4-gradeFix                           --
--============================================================--

local ESX
CreateThread(function()
    if pcall(function() ESX = exports['es_extended']:getSharedObject() end) and ESX then return end
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end)
        Wait(50)
    end
end)

local isOpen, currentJob = false, nil   -- job actuellement affiché

----------------------------------------------------------------
--  Ouverture / Fermeture                                     --
----------------------------------------------------------------
RegisterCommand('bossmenu', function() if isOpen then closeUI() else openUI() end end, false)
RegisterKeyMapping('bossmenu', 'Ouvrir/Fermer Boss-Menu', 'keyboard', 'F6')

function openUI(forcedJob)
    ESX.TriggerServerCallback('bossmenu:canOpen', function(ok, msg)
        if not ok then ESX.ShowNotification('~r~'..msg) return end
        ESX.TriggerServerCallback('bossmenu:getFullData', function(data)
            SetNuiFocus(true, true)
            SendNUIMessage({action = 'open', data = data})
            isOpen, currentJob = true, data.jobName
        end, forcedJob)
    end, forcedJob)
end

function closeUI()
    if not isOpen then return end
    isOpen, currentJob = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'forceClose'})
end

----------------------------------------------------------------
--  MAJ temps réel                                            --
----------------------------------------------------------------
RegisterNetEvent('bossmenu:updateUI', function(d)
    if isOpen and d.jobName == currentJob then
        SendNUIMessage({action = 'refresh', data = d})
    end
end)

----------------------------------------------------------------
--  NUI  →  Serveur                                            --
----------------------------------------------------------------
local function reply(_, cb) cb('ok') end
local function send(ev, payload)
    TriggerServerEvent(ev, payload, currentJob)     -- on passe toujours le job ciblé
end

RegisterNUICallback('luaClose',        function(d, cb) closeUI()                                                reply(d, cb) end)
RegisterNUICallback('createGrade',     function(d, cb) send('bossmenu:createGrade',      d)                     reply(d, cb) end)
RegisterNUICallback('updateGrade',     function(d, cb) send('bossmenu:updateGrade',      d)                     reply(d, cb) end)
RegisterNUICallback('deleteGrade',     function(id,cb) send('bossmenu:deleteGrade',      id)                    reply(id,cb) end)
RegisterNUICallback('setDefaultGrade', function(id,cb) send('bossmenu:setDefaultGrade',  id)                    reply(id,cb) end)

RegisterNUICallback('setEmployeeGrade', function(d, cb)
    if d.targetId and d.newGrade then
        send('bossmenu:setEmployeeGrade', {targetId=d.targetId,newGrade=d.newGrade})
    end
    reply(d, cb)
end)

RegisterNUICallback('invitePlayer',    function(d, cb) send('bossmenu:invitePlayer',     d)                     reply(d, cb) end)
RegisterNUICallback('kickPlayer',      function(d, cb) send('bossmenu:kickPlayer',       d)                     reply(d, cb) end)

----------------------------------------------------------------
--  ESC pour fermer                                           --
----------------------------------------------------------------
CreateThread(function()
    while true do
        if isOpen and not IsNuiFocused() and IsControlJustReleased(0, 322) then
            closeUI()
        end
        Wait(0)
    end
end)

----------------------------------------------------------------
--  Ouverture forcée depuis l’Admin-Menu                      --
----------------------------------------------------------------
RegisterNetEvent('bossmenu:forceOpenForJob', function(jobName)
    openUI(jobName)
end)
