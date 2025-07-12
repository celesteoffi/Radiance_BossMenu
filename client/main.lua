--============================================================--
-- Boss-Menu – CLIENT  v3.3-fix                                --
--============================================================--

local ESX
CreateThread(function()
  if pcall(function() ESX = exports['es_extended']:getSharedObject() end) and ESX then return end
  while ESX == nil do TriggerEvent('esx:getSharedObject', function(o) ESX=o end) Wait(50) end
end)

local menuOpen = false

-- --- Toggle F6 / commande -----------------------------------
RegisterCommand('bossmenu', function() if menuOpen then close() else open() end end, false)
RegisterKeyMapping('bossmenu','Ouvrir/Fermer Boss-Menu','keyboard','F6')

function open()
  if menuOpen or not ESX then return end
  ESX.TriggerServerCallback('bossmenu:canOpen', function(ok,msg)
    if not ok then ESX.ShowNotification('~r~'..msg) return end
    ESX.TriggerServerCallback('bossmenu:getFullData', function(d)
      SetNuiFocus(true,true)
      SendNUIMessage({action='open',data=d})
      menuOpen=true
    end)
  end)
end
function close()
  if not menuOpen then return end
  menuOpen=false
  SetNuiFocus(false,false)
  SendNUIMessage({action='forceClose'})
end

-- --- Mises à jour live --------------------------------------
RegisterNetEvent('bossmenu:updateUI', function(d)
  if menuOpen then SendNUIMessage({action='refresh',data=d}) end
end)

-- --- Callbacks NUI -> Lua -> serveur ------------------------
local function cbOK(_,cb) cb('ok') end

RegisterNUICallback('luaClose',        function(d,cb) close()                             cbOK(d,cb) end)
RegisterNUICallback('createGrade',     function(d,cb) TriggerServerEvent('bossmenu:createGrade',d)          cbOK(d,cb) end)
RegisterNUICallback('updateGrade',     function(d,cb) TriggerServerEvent('bossmenu:updateGrade',d)          cbOK(d,cb) end)
RegisterNUICallback('deleteGrade',     function(id,cb)TriggerServerEvent('bossmenu:deleteGrade',id)         cbOK(id,cb) end)
RegisterNUICallback('setDefaultGrade', function(id,cb)TriggerServerEvent('bossmenu:setDefaultGrade',id)     cbOK(id,cb) end)  -- 🟢 NOUVEAU
RegisterNUICallback('invitePlayer',    function(d,cb) TriggerServerEvent('bossmenu:invitePlayer',d.targetId)cbOK(d,cb) end)
RegisterNUICallback('kickPlayer',      function(d,cb) TriggerServerEvent('bossmenu:kickPlayer',d.targetId)  cbOK(d,cb) end)
RegisterNUICallback('setEmployeeGrade',function(d,cb) TriggerServerEvent('bossmenu:setEmployeeGrade',d.targetId,d.newGrade) cbOK(d,cb) end)

-- --- ESC en jeu --------------------------------------------
CreateThread(function()
  while true do
    if menuOpen and not IsNuiFocused() and IsControlJustReleased(0,322) then close() end
    Wait(0)
  end
end)
