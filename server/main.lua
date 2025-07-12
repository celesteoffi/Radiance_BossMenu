--============================================================--
--  Boss-Menu – SERVER  v3.4-gradeFix                         --
--============================================================--

--------------------------- ESX ---------------------------------
local ESX
if pcall(function() ESX = exports['es_extended']:getSharedObject() end) and ESX then
else AddEventHandler('esx:getSharedObject', function(o) ESX = o end) while not ESX do Wait(50) end end

------------------------- Cache ---------------------------------
-- cache[job] = {grades={}, invites={}, default='id'}
local cache = {}

MySQL.ready(function()
    for _,r in ipairs(MySQL.query.await('SELECT * FROM job_grades')) do
        cache[r.job_name]                = cache[r.job_name] or {grades={},invites={}}
        cache[r.job_name].grades[tostring(r.grade)] = {
            label       = r.label,
            salary      = r.salary,
            permissions = json.decode(r.permissions or '{}')
        }
    end
    for _,d in ipairs(MySQL.query.await('SELECT job_name,default_grade FROM bossmenu_defaults')) do
        cache[d.job_name]                = cache[d.job_name] or {grades={},invites={}}
        cache[d.job_name].default        = tostring(d.default_grade)
    end
end)

------------------------- Helpers -------------------------------
local function employees(job)
    local out={} for _,x in pairs(ESX.GetExtendedPlayers('job',job)) do
        out[#out+1] = {id=x.source,name=x.getName(),grade=x.job.grade,gradeLabel=x.job.grade_label}
    end
    return out
end
local function jobData(job) return {jobName=job,grades=cache[job].grades,default=cache[job].default,employees=employees(job)} end
local function push(job) TriggerClientEvent('bossmenu:updateUI',-1,jobData(job)) end
local function safeName(l) return (l:gsub('%s+','_'):gsub('[^%w_]',''):lower():gsub('^$','grade'..math.random(1000,9999))) end

-- admin whitelist : peut gérer n’importe quel job
local WL={} for _,r in ipairs(MySQL.query.await('SELECT discord_id FROM admin_whitelist')) do WL[r.discord_id]=true end
local function isAdmin(src) for _,id in ipairs(GetPlayerIdentifiers(src)) do if id:find('discord:') and WL[id] then return true end end end

local function hasPerm(ply, job, flag)
    if isAdmin(ply.source) and job ~= ply.job.name then return true end
    local cfg=Config.WhitelistedJobs[job]; if not cfg then return false end
    if ply.job.name==job and ply.job.grade==cfg.bossGrade then return true end
    local g=cache[job].grades[tostring(ply.job.grade)]
    return g and g.permissions and g.permissions[flag]
end

----------------------- Callbacks -------------------------------
ESX.RegisterServerCallback('bossmenu:canOpen',function(src,cb,forced)
  if forced then cb(true) return end
  local x=ESX.GetPlayerFromId(src); local cfg=Config.WhitelistedJobs[x.job.name]
  if not cfg then cb(false,'Job non autorisé.') return end
  if x.job.grade==cfg.bossGrade then cb(true) return end
  local g=cache[x.job.name].grades[tostring(x.job.grade)]
  cb(g and g.permissions and g.permissions.manage_grades,'Grade insuffisant.')
end)

ESX.RegisterServerCallback('bossmenu:getFullData',function(src,cb,forcedJob)
  local job = forcedJob or ESX.GetPlayerFromId(src).job.name
  cb(jobData(job))
end)

-- petite fonction utilitaire : quel job manipuler ?
local function targetJob(src, jobParam)
  return jobParam or ESX.GetPlayerFromId(src).job.name
end

----------------------- CRUD Grades ------------------------------
RegisterNetEvent('bossmenu:createGrade',function(d,job)
  local x=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(x,job,'manage_grades') then return end
  local id=tostring(d.grade); if cache[job].grades[id] then return end
  cache[job].grades[id]={label=d.label,salary=d.salary,permissions=d.permissions or {}}
  MySQL.executeSync('INSERT INTO job_grades (job_name,grade,name,label,salary,permissions) VALUES (?,?,?,?,?,?)',
    {job,id,safeName(d.label),d.label,d.salary,json.encode(d.permissions or {})})
  push(job)
end)

RegisterNetEvent('bossmenu:updateGrade',function(d,job)
  local x=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(x,job,'manage_grades') then return end
  local g=cache[job].grades[tostring(d.grade)]; if not g then return end
  g.label=d.label or g.label; g.salary=d.salary or g.salary; g.permissions=d.permissions or g.permissions
  MySQL.executeSync('UPDATE job_grades SET label=?,salary=?,permissions=? WHERE job_name=? AND grade=?',
    {g.label,g.salary,json.encode(g.permissions),job,tostring(d.grade)})
  push(job)
end)

RegisterNetEvent('bossmenu:deleteGrade',function(id,job)
  local x=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(x,job,'manage_grades') then return end
  id=tostring(id); if id==cache[job].default then return end
  if employees(job)[1] then for _,e in pairs(employees(job)) do if tostring(e.grade)==id then return end end end
  cache[job].grades[id]=nil
  MySQL.executeSync('DELETE FROM job_grades WHERE job_name=? AND grade=? LIMIT 1',{job,id})
  push(job)
end)

RegisterNetEvent('bossmenu:setDefaultGrade',function(id,job)
  local x=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(x,job,'manage_grades') then return end
  id=tostring(id); if not cache[job].grades[id] then return end
  cache[job].default=id
  MySQL.executeSync('REPLACE INTO bossmenu_defaults (job_name,default_grade) VALUES (?,?)',{job,id})
  push(job)
end)

----------------- Employés & permissions -------------------------
RegisterNetEvent('bossmenu:setEmployeeGrade', function(d, job)
  local admin  = ESX.GetPlayerFromId(source)
  job          = targetJob(source, job)          -- job ouvert dans l’UI
  local tgt    = ESX.GetPlayerFromId(d.targetId)
  local grade  = tostring(d.newGrade)

  -- autorisation :
  --  • admin absolu (whitelist)    OU
  --  • manage_grades / recruit     sur le job concerné
  if not (isAdmin(source)
          or hasPerm(admin, job, 'manage_grades')
          or hasPerm(admin, job, 'recruit')) then
      return
  end

  -- le grade doit exister dans ce job
  if tgt and cache[job].grades[grade] then
      tgt.setJob(job, tonumber(grade))
      push(job)                               -- refresh UI pour tous
  end
end)

RegisterNetEvent('bossmenu:invitePlayer',function(d,job)
  local b=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(b,job,'recruit') then return end
  cache[job].invites[d.targetId]=true
  TriggerClientEvent('esx:showNotification',d.targetId,('Invitation ~b~%s~s~ : /jobaccept'):format(job))
end)

RegisterNetEvent('bossmenu:kickPlayer',function(d,job)
  local b=ESX.GetPlayerFromId(source); job=targetJob(source,job)
  if not hasPerm(b,job,'kick') then return end
  local tgt=ESX.GetPlayerFromId(d.targetId)
  if tgt and tgt.job.name==job then tgt.setJob('unemployed',0); push(job) end
end)

ESX.RegisterCommand('jobaccept','user',function(p)
  for j,c in pairs(cache) do
    if c.invites[p.source] then
      p.setJob(j, tonumber(c.default or 0))
      c.invites[p.source]=nil
      push(j)
      return
    end
  end
  p.showNotification('Aucune invitation.')
end,false)

------------------------------------------------------------------
--  Reception d'un nouveau job (créé depuis l'admin-menu)        --
------------------------------------------------------------------
RegisterNetEvent('bossmenu:registerNewJob', function(data)
  local job   = data.name
  local label = data.label
  local sal   = data.salary
  local bossG = tostring(data.bossG)

  cache[job]               = cache[job] or {grades={},invites={},default='0'}
  cache[job].grades['0']   = {label = label..' Employé', salary = sal,  permissions = {}}
  cache[job].grades[bossG] = {label = label..' Boss',    salary = sal,  permissions = {manage_grades=true,recruit=true,kick=true}}
  -- on laisse cache[job].default à "0" (employé)

  -- pousse la mise à jour à tous les joueurs pour ce job
  push(job)
end)