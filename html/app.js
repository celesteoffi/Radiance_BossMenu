/* =============================================================
   Boss-Menu – NUI  (version 3.3-fix)
   • 4 onglets : Grades · Employés · Permissions · Défaut
   • Toutes les fonctions globales déclarées AVANT utilisation
   ============================================================= */

/* ---------- Helpers DOM & NUI ---------- */
const $   = id  => document.getElementById(id);
const nui = (action, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method : 'POST',
    headers: { 'Content-Type': 'application/json' },
    body   : JSON.stringify(data)
  });

/* ---------- Références ---------- */
const BODY = document.body,
      MOD  = $('modal'),
      MT   = $('modalTitle'),
      MB   = $('modalBody'),
      OK   = $('modalOk'),
      NO   = $('modalCancel'),
      TG   = $('gradesTable'),
      TE   = $('empTable'),
      TP   = $('permTable'),
      TD   = $('defTable');

let modalCB = null;
let DEFAULT_GRADE = '0';

/* ---------- Modal ---------- */
function showModal(title, fields, cb) {
  MT.textContent = title;
  MB.innerHTML   = '';
  fields.forEach(f=>{
    if(f.type==='checkbox'){
      MB.insertAdjacentHTML('beforeend',
        `<label style="font-weight:600">${f.label}</label>
         <input id="${f.name}" type="checkbox" ${f.value?'checked':''}><br>`);
    } else {
      MB.insertAdjacentHTML('beforeend',
        `<label style="font-weight:600">${f.label}</label>
         <input id="${f.name}" type="${f.type||'text'}" value="${f.value??''}"><br>`);
    }
  });
  modalCB = cb;
  MOD.classList.remove('hidden');
}
function closeModal(ok){
  if(ok && modalCB){
    const d={};
    MB.querySelectorAll('input').forEach(i=>{
      d[i.id] = (i.type==='checkbox') ? i.checked : i.value;
    });
    modalCB(d);
  }
  modalCB = null;
  MOD.classList.add('hidden');
}
OK.onclick = () => closeModal(true);
NO.onclick = () => closeModal(false);

/* ---------- Rendu tables ---------- */
function drawGrades(gr){
  let h=`<thead><tr><th>ID</th><th>Grade</th><th>$</th><th></th><th></th></tr></thead><tbody>`;
  Object.entries(gr).forEach(([id,v])=>{
    h+=`<tr>
      <td>${id}</td><td>${v.label}</td><td>${v.salary}</td>
      <td><button onclick="editGrade(${id},'${v.label}',${v.salary})">✏️</button></td>
      <td><button onclick="deleteGrade(${id})">🗑️</button></td>
    </tr>`;
  });
  TG.innerHTML = h + '</tbody>';
}
function drawEmployees(list){
  let h=`<thead><tr><th>ID</th><th>Nom</th><th>Grade</th><th></th><th></th></tr></thead><tbody>`;
  list.forEach(e=>{
    h+=`<tr>
      <td>${e.id}</td><td>${e.name}</td><td>${e.gradeLabel} (${e.grade})</td>
      <td><button onclick="promote(${e.id})">↗️</button></td>
      <td><button onclick="kick(${e.id})">🗑️</button></td>
    </tr>`;
  });
  TE.innerHTML = h + '</tbody>';
}
function drawPerms(gr){
  let h=`<thead><tr><th>ID</th><th>Grade</th><th>manage_grades</th><th>recruit</th><th>kick</th><th></th></tr></thead><tbody>`;
  Object.entries(gr).forEach(([id,v])=>{
    const p=v.permissions||{};
    h+=`<tr><td>${id}</td><td>${v.label}</td>
      <td>${p.manage_grades?'✅':'❌'}</td>
      <td>${p.recruit?'✅':'❌'}</td>
      <td>${p.kick?'✅':'❌'}</td>
      <td><button onclick="editPerm(${id},${!!p.manage_grades},${!!p.recruit},${!!p.kick})">⚙️</button></td>
    </tr>`;
  });
  TP.innerHTML = h + '</tbody>';
}
function drawDefault(gr){
  const def = gr[DEFAULT_GRADE];
  TD.innerHTML = `<thead><tr><th>Grade par défaut</th><th>Salaire</th><th></th></tr></thead><tbody>
    <tr>
      <td>${def?def.label:'—'}</td>
      <td>${def?def.salary:'—'}</td>
      <td><button onclick="chooseDefault()">Changer</button></td>
    </tr></tbody>`;
}

/* ---------- Actions Grades ---------- */
window.newGrade = () => showModal('Nouveau grade',[
  {label:'ID', name:'id', type:'number'},
  {label:'Nom',name:'label'},
  {label:'Salaire',name:'sal',type:'number'}
], d=>{
  const id=parseInt(d.id,10), sal=parseInt(d.sal,10)||0;
  if(isNaN(id)||!d.label)return;
  nui('createGrade',{grade:id,label:d.label,salary:sal,permissions:{}});
});
window.editGrade = (id,l,s)=> showModal('Modifier grade',[
  {label:'Nom',name:'label',value:l},
  {label:'Salaire',name:'sal',type:'number',value:s}
], d=>{
  const sal=parseInt(d.sal,10); if(!d.label||isNaN(sal))return;
  nui('updateGrade',{grade:id,label:d.label,salary:sal});
});
window.deleteGrade = id => showModal('Supprimer grade ?',[],()=>nui('deleteGrade',id));
function chooseDefault(){
  showModal('Grade par défaut',[{label:'ID',name:'id',type:'number'}],d=>{
    const id=parseInt(d.id,10); if(!isNaN(id)) nui('setDefaultGrade',id);
  });
}

/* ---------- Actions Employés ---------- */
window.promote = id => showModal('Attribuer grade',[{label:'ID',name:'g',type:'number'}],d=>{
  const g=parseInt(d.g,10); if(!isNaN(g)) nui('setEmployeeGrade',{targetId:id,newGrade:g});
});
window.kick = id => showModal('Virer employé ?',[],()=>nui('kickPlayer',{targetId:id}));

/* ---------- Actions Permissions ---------- */
window.editPerm = (id,mg,re,ki)=>showModal('Permissions',[{label:'manage_grades',name:'mg',type:'checkbox',value:mg},{label:'recruit',name:'re',type:'checkbox',value:re},{label:'kick',name:'ki',type:'checkbox',value:ki}],d=>{
  nui('updateGrade',{grade:id,
    permissions:{manage_grades:d.mg,recruit:d.re,kick:d.ki}});
});

/* ---------- Boutons statiques ---------- */
$('btnNewGrade').onclick = newGrade;
$('btnInvite').onclick   = ()=> showModal('Inviter joueur',[{label:'ID',name:'id',type:'number'}],d=>{
  const id=parseInt(d.id,10); if(id) nui('invitePlayer',{targetId:id});
});
$('btnClose').onclick    = ()=> nui('luaClose');

/* ---------- Tabs ---------- */
document.querySelectorAll('.tabs button').forEach(btn=>{
  btn.onclick=e=>{
    document.querySelectorAll('.tabs button').forEach(b=>b.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
    e.target.classList.add('active');
    document.querySelector('.'+e.target.dataset.tab).classList.add('active');
  };
});

/* ---------- Messages FiveM ---------- */
window.addEventListener('message',e=>{
  const {action,data}=e.data;
  if(action==='open'){
    DEFAULT_GRADE = data.default || '0';
    drawGrades(data.grades); drawEmployees(data.employees);
    drawPerms(data.grades);  drawDefault(data.grades);
    $('jobTitle').textContent = data.jobName;
    $('app').classList.remove('hidden'); BODY.classList.add('showUI');
  }
  else if(action==='refresh'){
    DEFAULT_GRADE = data.default || DEFAULT_GRADE;
    drawGrades(data.grades); drawEmployees(data.employees);
    drawPerms(data.grades);  drawDefault(data.grades);
  }
  else if(action==='forceClose'){
    $('app').classList.add('hidden'); BODY.classList.remove('showUI');
  }
});

/* ---------- ESC ---------- */
window.addEventListener('keydown',e=>{
  if(e.key==='Escape'){
    if(!MOD.classList.contains('hidden')) closeModal(false);
    else nui('luaClose');
  }
});
