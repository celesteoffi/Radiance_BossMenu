--============================================================--
--  Boss-Menu – SERVER v3.3                                   --
--  • paramètre defaultGrade + salaires appliqués à l’arrivée --
--============================================================--

-------------------------------- ESX -------------------------------
local ESX
if pcall(function() ESX = exports['es_extended']:getSharedObject() end) and ESX then
else AddEventHandler('esx:getSharedObject', function(o) ESX = o end) while ESX==nil do Wait(50) end end

------------------------------ Cache -------------------------------
local cache = {}          -- { [job] = { grades = {}, invites = {}, default = 'id' } }

MySQL.ready(function()
  for _,r in ipairs(MySQL.query.await('SELECT * FROM job_grades')) do
    cache[r.job_name]               = cache[r.job_name] or {grades={},invites={}}
    cache[r.job_name].grades[tostring(r.grade)] = {label=r.label,salary=r.salary,permissions=json.decode(r.permissions or '{}')}
  end
  local defs = MySQL.query.await('SELECT job_name,default_grade FROM bossmenu_defaults')
  for _,d in ipairs(defs) do
    cache[d.job_name]               = cache[d.job_name] or {grades={},invites={}}
    cache[d.job_name].default       = tostring(d.default_grade)
  end
end)

------------------------------ Helpers -----------------------------
local function employees(job)
  local t={} for _,x in pairs(ESX.GetExtendedPlayers('job',job)) do
    t[#t+1]={id=x.source,name=x.getName(),grade=x.job.grade,gradeLabel=x.job.grade_label} end
  return t
end
local function sendUpdate(job)
  TriggerClientEvent('bossmenu:updateUI', -1, {
    jobName   = job,
    grades    = cache[job].grades,
    default   = cache[job].default,
    employees = employees(job)
  })
end
local function hasPerm(p,flag)
  local cfg=Config.WhitelistedJobs[p.job.name]; if not cfg then return false end
  if p.job.grade==cfg.bossGrade then return true end
  local g=cache[p.job.name].grades[tostring(p.job.grade)]
  return g.permissions and g.permissions[flag]
end
local function safeName(l) return (l:gsub('%s+','_'):gsub('[^%w_]',''):lower():gsub('^$','grade'..math.random(1000,9999))) end

--------------------------- Callbacks -----------------------------
ESX.RegisterServerCallback('bossmenu:canOpen', function(src,cb)
  local x=ESX.GetPlayerFromId(src);local cfg=Config.WhitelistedJobs[x.job.name]
  if not cfg then        cb(false,'Job non autorisé.')   return end
  if x.job.grade==cfg.bossGrade then cb(true) return end
  local g=cache[x.job.name].grades[tostring(x.job.grade)]
  cb(g and g.permissions and g.permissions.manage_grades,'Grade insuffisant.')
end)
ESX.RegisterServerCallback('bossmenu:getFullData',function(s,cb)
  local j=ESX.GetPlayerFromId(s).job.name
  cb{jobName=j,grades=cache[j].grades,default=cache[j].default,employees=employees(j)}
end)

----------------------- Création / MAJ grade -----------------------
RegisterNetEvent('bossmenu:createGrade',function(d)
  local x=ESX.GetPlayerFromId(source);if not hasPerm(x,'manage_grades')then return end
  local j=x.job.name;local id=tostring(d.grade)
  if cache[j].grades[id]then x.showNotification('ID déjà pris.');return end
  cache[j].grades[id]={label=d.label,salary=d.salary,permissions=d.permissions or {}}
  MySQL.executeSync('INSERT INTO job_grades (job_name,grade,name,label,salary,permissions) VALUES (?,?,?,?,?,?)',
    {j,id,safeName(d.label),d.label,d.salary,json.encode(d.permissions or {})})
  sendUpdate(j)
end)

RegisterNetEvent('bossmenu:updateGrade',function(d)
  local x=ESX.GetPlayerFromId(source);if not hasPerm(x,'manage_grades')then return end
  local j=x.job.name;local id=tostring(d.grade);local g=cache[j].grades[id]if not g then return end
  g.salary=d.salary or g.salary;g.label=d.label or g.label;g.permissions=d.permissions or g.permissions
  MySQL.executeSync('UPDATE job_grades SET label=?,salary=?,permissions=? WHERE job_name=? AND grade=?',
    {g.label,g.salary,json.encode(g.permissions),j,id})
  sendUpdate(j)
end)

RegisterNetEvent('bossmenu:deleteGrade',function(id)
  local x=ESX.GetPlayerFromId(source);if not hasPerm(x,'manage_grades')then return end
  local j=x.job.name;id=tostring(id)
  if id==cache[j].default then x.showNotification('Définissez d\'abord un autre grade par défaut.');return end
  if not cache[j].grades[id]then return end
  for _,e in pairs(employees(j))do if tostring(e.grade)==id then x.showNotification('Des employés ont ce grade.') return end end
  cache[j].grades[id]=nil
  MySQL.executeSync('DELETE FROM job_grades WHERE job_name=? AND grade=? LIMIT 1',{j,id})
  sendUpdate(j)
end)

----------------------- Défaut grade -------------------------------
RegisterNetEvent('bossmenu:setDefaultGrade',function(id)
  local x=ESX.GetPlayerFromId(source);if not hasPerm(x,'manage_grades')then return end
  local j=x.job.name;id=tostring(id)
  if not cache[j].grades[id]then return end
  cache[j].default=id
  MySQL.executeSync('REPLACE INTO bossmenu_defaults (job_name,default_grade) VALUES (?,?)',{j,id})
  sendUpdate(j)
end)

----------------------- Changer grade employé ----------------------
RegisterNetEvent('bossmenu:setEmployeeGrade',function(tid,newG)
  local b=ESX.GetPlayerFromId(source);if not hasPerm(b,'manage_grades')then return end
  local t=ESX.GetPlayerFromId(tid);newG=tostring(newG)
  if t and t.source~=b.source and t.job.name==b.job.name and cache[t.job.name].grades[newG]then
    t.setJob(t.job.name,tonumber(newG)); sendUpdate(t.job.name)
  end
end)

----------------------- Recruit / Accept / Kick --------------------
RegisterNetEvent('bossmenu:invitePlayer',function(t)
  local b=ESX.GetPlayerFromId(source);if not hasPerm(b,'recruit')then return end
  cache[b.job.name].invites[t]=true;TriggerClientEvent('esx:showNotification',t,
   ('Invitation ~b~%s~s~ : /jobaccept'):format(b.job.name))
end)
ESX.RegisterCommand('jobaccept','user',function(p)
  for j,c in pairs(cache)do if c.invites[p.source]then p.setJob(j,tonumber(c.default or 0));c.invites[p.source]=nil;sendUpdate(j) return end end
  p.showNotification('Aucune invitation.')
end,false)
RegisterNetEvent('bossmenu:kickPlayer',function(t)
  local b=ESX.GetPlayerFromId(source);if not hasPerm(b,'kick')then return end
  local p=ESX.GetPlayerFromId(t)
  if p and p.source~=b.source and p.job.name==b.job.name then p.setJob('unemployed',0);sendUpdate(b.job.name) end
end)
