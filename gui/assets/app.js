const DATA = __DATA_JSON__;

const TABS = [
  {id:'overview',label:'Overview'},
  {id:'pcm',label:'PCM Benchmark'},
  {id:'quality',label:'Quality & Convergence'},
  {id:'schedule',label:'Schedule'},
  {id:'reports',label:'Reports'},
  {id:'run',label:'Run Tasks'},
  {id:'settings',label:'Settings'}
];
const ACOL = {
  benchmark_uc:'#3b82f6', benders:'#ef4444', ccg:'#10b981',
  standard:'#64748b', clustered_pcm:'#f59e0b', adaptive_overlap:'#06b6d4', clustered_adaptive_overlap:'#8b5cf6'
};
const ALABEL = {
  benchmark_uc:'Benchmark UC', benders:'Benders', ccg:'CCG',
  standard:'Standard PCM', clustered_pcm:'Clustered PCM',
  adaptive_overlap:'Adaptive Overlap', clustered_adaptive_overlap:'Clustered Adaptive'
};
const C10 = ['#3b82f6','#ef4444','#10b981','#f59e0b','#06b6d4','#8b5cf6','#ec4899','#14b8a6','#f97316','#6366f1'];
const PLCFG = {responsive:true,displayModeBar:true,displaylogo:false,modeBarButtonsToRemove:['lasso2d','select2d','autoScale2d'],toImageButtonOptions:{format:'png',height:600,width:1000,scale:2}};
const PLMARGIN = {l:58,r:18,t:24,b:46};
let qlActive='curtailment';
let scActive='dispatch';
let pcmActiveView='perf';
let runPollTimer = null;
let activeSvgChart = '';
let svgZoom = 1;
let themeObserver = null;

function $(id){return document.getElementById(id);}
function fmt(n,d){if(n===null||n===undefined||n==='')return'—';const v=Number(n);return Number.isNaN(v)?String(n):v.toFixed(d===undefined?2:d);}
function pl(id){const d=document.getElementById(id);if(d)Plotly.purge(d);return d;}
function getPlotTheme(){
  const dark=isDarkTheme();
  return {
    paper_bgcolor:'rgba(0,0,0,0)',
    plot_bgcolor:'rgba(0,0,0,0)',
    font:{color:dark?'#e5e7eb':'#1e293b',size:11},
    gridcolor:dark?'#374151':'#e2e8f0'
  };
}
function show(id,data,layout){
  const th=getPlotTheme();
  const base={
    height:480,margin:PLMARGIN,hovermode:'x unified',
    paper_bgcolor:th.paper_bgcolor,plot_bgcolor:th.plot_bgcolor,font:th.font,
    legend:{orientation:'h',y:-0.2,x:0},
    xaxis:{tickfont:{size:10},gridcolor:th.gridcolor},
    yaxis:{tickfont:{size:10},title:{font:{size:11}},gridcolor:th.gridcolor}
  };
  const merged=Object.assign({},base,layout||{});
  merged.xaxis=Object.assign({},base.xaxis,(layout&&layout.xaxis)||{});
  merged.yaxis=Object.assign({},base.yaxis,(layout&&layout.yaxis)||{});
  Plotly.newPlot(pl(id),data,merged,PLCFG);
}
function showCompact(id,data,layout,h){
  const th=getPlotTheme();
  const base={
    height:h||310,margin:{l:56,r:16,t:16,b:44},hovermode:'closest',
    paper_bgcolor:th.paper_bgcolor,plot_bgcolor:th.plot_bgcolor,font:th.font,
    legend:{orientation:'h',y:-0.24,x:0,font:{size:10}},
    xaxis:{tickfont:{size:10},gridcolor:th.gridcolor},
    yaxis:{tickfont:{size:10},title:{font:{size:10}},gridcolor:th.gridcolor}
  };
  const merged=Object.assign({},base,layout||{});
  merged.xaxis=Object.assign({},base.xaxis,(layout&&layout.xaxis)||{});
  merged.yaxis=Object.assign({},base.yaxis,(layout&&layout.yaxis)||{});
  Plotly.newPlot(pl(id),data,merged,PLCFG);
}
function methodPill(m){
  const c=ACOL[m]||'#64748b';
  const lbl=ALABEL[m]||m;
  return '<span class="method-pill"><span class="method-dot" style="background:'+c+'"></span>'+escapeHTML(lbl)+'</span>';
}

function init(){
  try{var s=localStorage.getItem('uc-theme');}catch(e){s=null;}
  if(s)document.documentElement.dataset.theme=s;
  buildThemeSwitcher();buildNav();
  initThemeWatcher();
  renderOverview();renderPcm();renderQuality();renderSchedule();renderReports();renderSettings();
}

const THEMES=[{id:'',label:'Default',color:'#2563eb'},{id:'dark',label:'Dark',color:'#1f2937'},{id:'forest',label:'Forest',color:'#059669'},{id:'sunset',label:'Sunset',color:'#ea580c'},{id:'ocean',label:'Ocean',color:'#0284c7'}];

function buildThemeSwitcher(){
  const c=document.documentElement.dataset.theme||'';
  $('theme-switcher').innerHTML=THEMES.map(function(t){return'<div class="theme-dot'+(t.id===c?' active':'')+'" data-theme="'+t.id+'" title="'+t.label+'" style="background:'+t.color+'"></div>';}).join('');
  $('theme-switcher').onclick=function(e){const d=e.target.closest('.theme-dot');if(!d)return;const t=d.dataset.theme;document.documentElement.dataset.theme=t;document.querySelectorAll('.theme-dot').forEach(function(x){x.classList.remove('active');});d.classList.add('active');try{localStorage.setItem('uc-theme',t);}catch(e){}applyReportTheme();renderOverviewCharts();renderPcmView();switchQl();switchSc();};
}

function initThemeWatcher(){
  if(themeObserver)themeObserver.disconnect();
  themeObserver=new MutationObserver(function(){applyReportTheme();});
  themeObserver.observe(document.documentElement,{attributes:true,attributeFilter:['data-theme','class']});
  if(document.body)themeObserver.observe(document.body,{attributes:true,attributeFilter:['class']});
  applyReportTheme();
}

function isDarkTheme(){
  const rootTheme=document.documentElement.dataset.theme||'';
  const bodyClass=document.body?document.body.className:'';
  const rootClass=document.documentElement.className||'';
  return rootTheme==='dark'||bodyClass.indexOf('dark-theme')>=0||bodyClass.indexOf('dark')>=0||String(rootClass).indexOf('dark-theme')>=0;
}

function buildNav(){
  $('nav').innerHTML=TABS.map(function(t,i){return'<button class="nav-btn'+(i===0?' active':'')+'" data-tab="'+t.id+'">'+t.label+'</button>';}).join('');
  $('nav').onclick=function(e){const b=e.target.closest('button');if(!b)return;const tid=b.dataset.tab;document.querySelectorAll('.nav-btn').forEach(function(x){x.classList.remove('active');});b.classList.add('active');document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('active');});$('tab-'+tid).classList.add('active');if(tid==='overview')renderOverviewCharts();if(tid==='pcm')renderPcmView();if(tid==='quality')renderQuality();if(tid==='schedule')renderSchedule();if(tid==='reports')renderReports();if(tid==='run')checkJuliaStatus();};
}

// ============ OVERVIEW ============
function renderOverview(){
  const runs=Object.keys(DATA.summaries||{}).sort().reverse();
  var total=0,ok=0,conv=0,err=0,bestGap=Infinity,fastest=null;
  const allAlgos=new Set();
  for(const[k,v]of Object.entries(DATA.summaries||{})){
    if(!v||v.length<2)continue;
    for(var i=1;i<v.length;i++){
      total++;
      allAlgos.add(v[i][0]);
      const st=(v[i][2]||'').toLowerCase();
      if(st==='optimal')ok++;else if(st==='converged')conv++;else if(st.includes('inconsistency')||st.includes('error')||st.includes('fail'))err++;
      const g=parseFloat(v[i][6]); if(!Number.isNaN(g)&&g>=0&&g<bestGap)bestGap=g;
      const t=parseFloat(v[i][7]); if(!Number.isNaN(t)&&t>0&&(!fastest||t<fastest.t))fastest={t:t,algo:v[i][0],scen:v[i][1]};
    }
  }
  let pcmMaxSpeedup=0,pcmMaxRed=0;
  Object.values(DATA.pcm_benchmarks||{}).forEach(function(ds){
    (ds.rows||[]).forEach(function(r){
      if(r.speedup&&r.speedup>pcmMaxSpeedup)pcmMaxSpeedup=r.speedup;
      if(r.state_reduction_pct&&r.state_reduction_pct>pcmMaxRed)pcmMaxRed=r.state_reduction_pct;
    });
  });
  const successRate=total?((ok+conv)/total*100).toFixed(1)+'%':'—';
  $('overview-metrics').innerHTML=[
    '<div class="metric" style="--metric-accent:#3b82f6"><div class="label">UC Benchmark Runs</div><div class="value">'+runs.length+'</div><div class="sub">'+total+' total solver records</div></div>',
    '<div class="metric" style="--metric-accent:#10b981"><div class="label">UC Success Rate</div><div class="value" style="color:#16a34a">'+successRate+'</div><div class="sub">'+ok+' optimal &middot; '+conv+' converged &middot; '+err+' failed</div></div>',
    '<div class="metric" style="--metric-accent:#06b6d4"><div class="label">Fastest UC Solve</div><div class="value">'+(fastest?fmt(fastest.t,2)+'s':'—')+'</div><div class="sub">'+(fastest?(ALABEL[fastest.algo]||fastest.algo)+' ('+fastest.scen+' scen)':'No local UC runs')+'</div></div>',
    '<div class="metric" style="--metric-accent:#8b5cf6"><div class="label">Best Optimality Gap</div><div class="value">'+(bestGap<Infinity?(bestGap*100).toFixed(3)+'%':'—')+'</div><div class="sub">Minimum relative MIP/decomposition gap</div></div>',
    '<div class="metric" style="--metric-accent:#f59e0b"><div class="label">PCM Peak Speedup</div><div class="value">'+(pcmMaxSpeedup?pcmMaxSpeedup.toFixed(2)+'&times;':'—')+'</div><div class="sub">1080-unit clustered adaptive vs standard</div></div>',
    '<div class="metric" style="--metric-accent:#ec4899"><div class="label">Max State Reduction</div><div class="value">'+(pcmMaxRed?pcmMaxRed.toFixed(1)+'%':'—')+'</div><div class="sub">Equivalent units compression (1080 &rarr; 31)</div></div>'
  ].join('');

  $('ov-run').innerHTML=runs.length?runs.map(function(r){return'<option value="'+escapeHTML(r)+'">'+escapeHTML(r)+'</option>';}).join(''):'<option value="">No local runs</option>';
  $('ov-algo').innerHTML='<option value="">All Algorithms</option>'+Array.from(allAlgos).sort().map(function(a){return'<option value="'+escapeHTML(a)+'">'+escapeHTML(ALABEL[a]||a)+'</option>';}).join('');
  $('ov-run').onchange=function(){renderOverviewCharts();renderOverviewTable();};
  $('ov-algo').onchange=function(){renderOverviewCharts();renderOverviewTable();};
  renderOverviewCharts();
  renderOverviewTable();
}

function renderOverviewCharts(){
  const run=$('ov-run')?$('ov-run').value:'';
  const algoFilter=$('ov-algo')?$('ov-algo').value:'';
  var rows=(DATA.summaries[run]||[]).slice(1);
  if(algoFilter)rows=rows.filter(function(r){return r[0]===algoFilter;});
  const ids=['ov-chart-time','ov-chart-gap','ov-chart-obj','ov-chart-ram'];
  if(!rows.length){
    ids.forEach(function(id){const el=$(id);if(el)el.innerHTML='<div class="empty-state" style="height:310px;display:flex;align-items:center;justify-content:center;">No UC comparison run selected. Run UC Benchmark or check PCM Benchmark tab.</div>';});
    return;
  }
  const xLabels=rows.map(function(r){return(ALABEL[r[0]]||r[0])+' ('+r[1]+'s)';});
  const colors=rows.map(function(r){return ACOL[r[0]]||'#3b82f6';});

  showCompact('ov-chart-time',[{
    type:'bar',x:xLabels,y:rows.map(function(r){return +r[7];}),
    text:rows.map(function(r){return fmt(r[7],2)+'s';}),textposition:'auto',
    marker:{color:colors}
  }],{yaxis:{title:'Time (s)'},showlegend:false});

  const gaps=rows.map(function(r){return Math.max(parseFloat(r[6])||0,1e-8);});
  showCompact('ov-chart-gap',[{
    type:'bar',x:xLabels,y:gaps,
    text:rows.map(function(r){return ((parseFloat(r[6])||0)*100).toFixed(3)+'%';}),textposition:'auto',
    marker:{color:gaps.map(function(g){return g<0.01?'#10b981':g<0.1?'#f59e0b':'#ef4444';})}
  }],{yaxis:{title:'Gap',type:'log'},showlegend:false});

  showCompact('ov-chart-obj',[
    {type:'bar',name:'Lower Bound',x:xLabels,y:rows.map(function(r){return +r[4];}),marker:{color:'#3b82f6'}},
    {type:'bar',name:'Upper Bound',x:xLabels,y:rows.map(function(r){return +r[5];}),marker:{color:'#10b981'}}
  ],{barmode:'group',yaxis:{title:'Objective Cost'}});

  showCompact('ov-chart-ram',[{
    type:'bar',x:xLabels,y:rows.map(function(r){return +r[8];}),
    text:rows.map(function(r){return fmt(r[8],1)+' MB';}),textposition:'auto',
    marker:{color:colors}
  }],{yaxis:{title:'Peak RAM (MB)'},showlegend:false});
}

function renderOverviewTable(){
  const algoFilter=$('ov-algo')?$('ov-algo').value:'';
  var html='<thead><tr><th>Run</th><th>Algorithm</th><th>Scen</th><th>Status</th><th>Iter</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Time (s)</th><th>Speedup</th><th>RAM (MB)</th></tr></thead><tbody>';
  var count=0;
  for(const[run,rows]of Object.entries(DATA.summaries||{}).sort().reverse()){
    const baseByScen={};
    for(var j=1;j<rows.length;j++){if(rows[j][0]==='benchmark_uc')baseByScen[rows[j][1]]=parseFloat(rows[j][7]);}
    for(var i=1;i<rows.length;i++){
      const r=rows[i];
      if(algoFilter&&r[0]!==algoFilter)continue;
      count++;
      const gap=parseFloat(r[6]);
      const gc=gap<0.01?'gap-good':gap>0.5?'gap-bad':'';
      var b='',st=(r[2]||'').toLowerCase();
      if(st==='optimal')b='badge-ok';else if(st==='converged')b='badge-info';else if(st.includes('inconsistency')||st.includes('error')||st.includes('fail'))b='badge-err';else b='badge-warn';
      const t=parseFloat(r[7]), bt=baseByScen[r[1]];
      let spHtml='<span class="speedup-chip speedup-base">—</span>';
      if(bt&&t>0){const sp=bt/t;const cls=sp>=1.15?'speedup-fast':sp<0.85?'speedup-slow':'speedup-base';spHtml='<span class="speedup-chip '+cls+'">'+sp.toFixed(2)+'&times;</span>';}
      html+='<tr><td>'+escapeHTML(run)+'</td><td>'+methodPill(r[0])+'</td><td class="num">'+r[1]+'</td><td><span class="badge '+b+'">'+escapeHTML(r[2])+'</span></td><td class="num">'+r[3]+'</td><td class="num">'+fmt(r[4],1)+'</td><td class="num">'+fmt(r[5],1)+'</td><td class="num '+gc+'">'+(Number.isNaN(gap)?'—':gap.toFixed(5))+'</td><td class="num">'+fmt(r[7],2)+'</td><td>'+spHtml+'</td><td class="num">'+fmt(r[8],1)+'</td></tr>';
    }
  }
  if(!count)html+='<tr><td colspan="11" class="empty-state">No UC comparison summary records found.</td></tr>';
  html+='</tbody>';
  $('summary-table').innerHTML=html;
}

// ============ PCM BENCHMARK ============
function renderPcm(){
  const keys=Object.keys(DATA.pcm_benchmarks||{});
  $('pcm-dataset').innerHTML=keys.map(function(k){return'<option value="'+escapeHTML(k)+'">'+escapeHTML(DATA.pcm_benchmarks[k].label||k)+'</option>';}).join('');
  $('pcm-dataset').onchange=renderPcmView;
  $('pcm-profile').onchange=renderPcmView;
  const views=[
    {id:'perf',label:'Solve Time & Speedup'},
    {id:'cost',label:'Total Cost & Savings'},
    {id:'reduction',label:'Dimension Reduction & Feasibility'},
    {id:'pareto',label:'Time vs Cost Pareto'}
  ];
  $('pcm-view-tabs').innerHTML=views.map(function(v){return'<button class="view-tab'+(v.id===pcmActiveView?' active':'')+'" data-pview="'+v.id+'">'+v.label+'</button>';}).join('');
  $('pcm-view-tabs').onclick=function(e){
    const b=e.target.closest('.view-tab');if(!b)return;
    pcmActiveView=b.dataset.pview;
    document.querySelectorAll('#pcm-view-tabs .view-tab').forEach(function(x){x.classList.remove('active');});
    b.classList.add('active');
    renderPcmView();
  };
  renderPcmView();
}

function renderPcmView(){
  const key=$('pcm-dataset')?$('pcm-dataset').value:'';
  const ds=(DATA.pcm_benchmarks||{})[key];
  if(!ds)return;
  const profFilter=$('pcm-profile')?$('pcm-profile').value:'';
  const rows=(ds.rows||[]).filter(function(r){return !profFilter||r.profile===profFilter;});
  if($('pcm-source-tag'))$('pcm-source-tag').textContent=(ds.source||'Archive')+' · '+(ds.scale||'')+' · '+(ds.horizon||'');

  const okRows=rows.filter(function(r){return r.status==='OK'&&r.solve_time_s!=null;});
  const fastest=okRows.length?okRows.reduce(function(a,b){return a.solve_time_s<b.solve_time_s?a:b;}):null;
  const maxSp=rows.reduce(function(m,r){return r.speedup&&r.speedup>m?r.speedup:m;},0);
  const maxRed=rows.reduce(function(m,r){return r.state_reduction_pct&&r.state_reduction_pct>m?r.state_reduction_pct:m;},0);
  const extRows=rows.filter(function(r){return r.profile==='extreme_ramp';});
  const extOk=extRows.filter(function(r){return r.status==='OK';}).length;
  const bestSave=rows.reduce(function(best,r){return (r.cost_delta_pct!=null&&r.status==='OK'&&(best===null||r.cost_delta_pct<best.cost_delta_pct))?r:best;},null);

  $('pcm-metrics').innerHTML=[
    '<div class="metric" style="--metric-accent:#8b5cf6"><div class="label">Peak Speedup</div><div class="value">'+(maxSp?maxSp.toFixed(2)+'&times;':'—')+'</div><div class="sub">vs Standard PCM baseline</div></div>',
    '<div class="metric" style="--metric-accent:#06b6d4"><div class="label">Fastest Feasible Solve</div><div class="value">'+(fastest?fmt(fastest.solve_time_s,2)+'s':'—')+'</div><div class="sub">'+(fastest?(ALABEL[fastest.method]||fastest.method)+' ('+fastest.profile+')':'—')+'</div></div>',
    '<div class="metric" style="--metric-accent:#f59e0b"><div class="label">State Space Reduction</div><div class="value">'+(maxRed?maxRed.toFixed(1)+'%':'0.0%')+'</div><div class="sub">Clustered equivalent units compression</div></div>',
    '<div class="metric" style="--metric-accent:#10b981"><div class="label">Best Cost Delta</div><div class="value">'+(bestSave?(bestSave.cost_delta_pct>0?'+':'')+bestSave.cost_delta_pct.toFixed(2)+'%':'—')+'</div><div class="sub">'+(bestSave?(ALABEL[bestSave.method]||bestSave.method)+' ('+bestSave.profile+')':'—')+'</div></div>',
    '<div class="metric" style="--metric-accent:#ef4444"><div class="label">Extreme-Ramp Feasible</div><div class="value">'+(extRows.length?extOk+'/'+extRows.length:'—')+'</div><div class="sub">Adaptive overlap prevents boundary infeasibility</div></div>'
  ].join('');

  const profiles=Array.from(new Set(rows.map(function(r){return r.profile;})));
  const methods=['standard','clustered_pcm','adaptive_overlap','clustered_adaptive_overlap'].filter(function(m){return rows.some(function(r){return r.method===m;});});

  if(pcmActiveView==='perf'){
    $('pcm-chart1-title').textContent='Simulation Solve Time (s) — Lower is Better';
    $('pcm-chart2-title').textContent='Speedup Ratio vs Standard PCM (x) — Higher is Better';
    const s1=methods.map(function(m){
      return {
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.status==='OK';});return f?f.solve_time_s:null;}),
        text:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m;});return !f?'':f.status!=='OK'?'FAIL':fmt(f.solve_time_s,1)+'s';}),
        textposition:'auto',marker:{color:ACOL[m]||'#64748b'}
      };
    });
    showCompact('pcm-chart1',s1,{barmode:'group',yaxis:{title:'Solve Time (s)'}},400);

    const s2=methods.map(function(m){
      return {
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.speedup!=null;});return f?f.speedup:null;}),
        text:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.speedup!=null;});return f?f.speedup.toFixed(2)+'x':'';}),
        textposition:'auto',marker:{color:ACOL[m]||'#64748b'}
      };
    });
    showCompact('pcm-chart2',s2,{barmode:'group',yaxis:{title:'Speedup (x)'},shapes:[{type:'line',xref:'paper',x0:0,x1:1,y0:1,y1:1,line:{color:'#94a3b8',dash:'dot',width:1.5}}]},400);
  } else if(pcmActiveView==='cost'){
    $('pcm-chart1-title').textContent='Total Operating Cost (Million)';
    $('pcm-chart2-title').textContent='Cost Delta vs Standard PCM (%) — Negative = Savings';
    const s1=methods.map(function(m){
      return {
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.total_cost!=null;});return f?f.total_cost/1e6:null;}),
        text:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.total_cost!=null;});return f?(f.total_cost/1e6).toFixed(2)+'M':'';}),
        textposition:'auto',marker:{color:ACOL[m]||'#64748b'}
      };
    });
    showCompact('pcm-chart1',s1,{barmode:'group',yaxis:{title:'Total Cost (M)'}},400);

    const s2=methods.map(function(m){
      return {
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.cost_delta_pct!=null&&r.status==='OK';});return f?f.cost_delta_pct:null;}),
        text:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m&&r.cost_delta_pct!=null&&r.status==='OK';});return f?(f.cost_delta_pct>0?'+':'')+f.cost_delta_pct.toFixed(2)+'%':'';}),
        textposition:'auto',marker:{color:ACOL[m]||'#64748b'}
      };
    });
    showCompact('pcm-chart2',s2,{barmode:'group',yaxis:{title:'Cost Delta (%)'},shapes:[{type:'line',xref:'paper',x0:0,x1:1,y0:0,y1:0,line:{color:'#94a3b8',dash:'dot',width:1.5}}]},400);
  } else if(pcmActiveView==='reduction'){
    $('pcm-chart1-title').textContent='Equivalent Unit Count (Physical vs Clustered)';
    $('pcm-chart2-title').textContent='Feasibility Success Rate Across Load Profiles (%)';
    const sampleByMethod=methods.map(function(m){return rows.find(function(r){return r.method===m;})||{};});
    showCompact('pcm-chart1',[
      {type:'bar',name:'Physical Units',x:methods.map(function(m){return ALABEL[m]||m;}),y:sampleByMethod.map(function(r){return r.physical_units||0;}),marker:{color:'#94a3b8'}},
      {type:'bar',name:'Equivalent Units',x:methods.map(function(m){return ALABEL[m]||m;}),y:sampleByMethod.map(function(r){return r.equiv_units||0;}),text:sampleByMethod.map(function(r){return r.state_reduction_pct?'-'+r.state_reduction_pct.toFixed(1)+'%':'0%';}),textposition:'auto',marker:{color:methods.map(function(m){return ACOL[m]||'#3b82f6';})}}
    ],{barmode:'group',yaxis:{title:'Unit Count'}},400);

    const s2=methods.map(function(m){
      return {
        type:'bar',name:ALABEL[m]||m,x:profiles,
        y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m;});return f?f.success_rate:0;}),
        text:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m;});return f?f.success_rate.toFixed(0)+'%':'';}),
        textposition:'auto',marker:{color:ACOL[m]||'#64748b'}
      };
    });
    showCompact('pcm-chart2',s2,{barmode:'group',yaxis:{title:'Success Rate (%)',range:[0,115]}},400);
  } else {
    $('pcm-chart1-title').textContent='Solve Time vs Total Cost Pareto (Lower-Left is Better)';
    $('pcm-chart2-title').textContent='Mean Overlap Window & Peak RSS Memory';
    const symbols={baseline:'circle',smooth:'square',extreme_ramp:'diamond'};
    const s1=methods.map(function(m){
      const mr=rows.filter(function(r){return r.method===m&&r.status==='OK'&&r.solve_time_s!=null&&r.total_cost!=null;});
      return {
        type:'scatter',mode:'markers+text',name:ALABEL[m]||m,
        x:mr.map(function(r){return r.solve_time_s;}),
        y:mr.map(function(r){return r.total_cost/1e6;}),
        text:mr.map(function(r){return r.profile;}),textposition:'top center',
        marker:{size:13,color:ACOL[m]||'#3b82f6',symbol:mr.map(function(r){return symbols[r.profile]||'circle';}),line:{width:1.5,color:'#fff'}}
      };
    });
    showCompact('pcm-chart1',s1,{xaxis:{title:'Solve Time (s)'},yaxis:{title:'Total Cost (M)'}},400);

    const hasRss=rows.some(function(r){return r.peak_rss_mb!=null;});
    if(hasRss){
      const s2=methods.map(function(m){
        return {
          type:'bar',name:ALABEL[m]||m,x:profiles,
          y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m;});return f?f.peak_rss_mb:null;}),
          marker:{color:ACOL[m]||'#64748b'}
        };
      });
      showCompact('pcm-chart2',s2,{barmode:'group',yaxis:{title:'Peak RSS (MB)'}},400);
    } else {
      const s2=methods.map(function(m){
        return {
          type:'bar',name:ALABEL[m]||m,x:profiles,
          y:profiles.map(function(p){const f=rows.find(function(r){return r.profile===p&&r.method===m;});return f?(f.overlap_h||0):0;}),
          marker:{color:ACOL[m]||'#64748b'}
        };
      });
      showCompact('pcm-chart2',s2,{barmode:'group',yaxis:{title:'Mean Overlap Window (h)'}},400);
    }
  }

  var th='<thead><tr><th>Profile</th><th>Method</th><th>Status</th><th>Solve Time (s)</th><th>Speedup</th><th>Total Cost (M)</th><th>Cost Delta</th><th>Units (Phys &rarr; Equiv)</th><th>State Reduction</th><th>Overlap (h)</th><th>Peak RSS (MB)</th></tr></thead><tbody>';
  rows.forEach(function(r){
    const ok=r.status==='OK';
    const stBadge=ok?'<span class="badge badge-ok">OK</span>':'<span class="badge badge-err">INFEASIBLE</span>';
    let spHtml='<span class="speedup-chip speedup-base">—</span>';
    if(r.speedup!=null){const cls=r.speedup>=1.2?'speedup-fast':r.speedup<0.85?'speedup-slow':'speedup-base';spHtml='<span class="speedup-chip '+cls+'">'+r.speedup.toFixed(2)+'&times;</span>';}
    let cdHtml='—';
    if(r.cost_delta_pct!=null&&ok){const cls=r.cost_delta_pct<=-0.1?'gap-good':r.cost_delta_pct>2?'gap-bad':'';cdHtml='<span class="'+cls+'">'+(r.cost_delta_pct>0?'+':'')+r.cost_delta_pct.toFixed(2)+'%</span>';}
    const red=r.state_reduction_pct||0;
    const redBar='<div class="bar-wrap"><div class="bar-track"><div class="bar-fill" style="width:'+Math.min(100,Math.max(0,red))+'%;background:'+(ACOL[r.method]||'#3b82f6')+'"></div></div><span class="num">'+red.toFixed(1)+'%</span></div>';
    th+='<tr><td><strong>'+escapeHTML(r.profile)+'</strong></td><td>'+methodPill(r.method)+'</td><td>'+stBadge+'</td><td class="num">'+(ok&&r.solve_time_s!=null?fmt(r.solve_time_s,2):'—')+'</td><td>'+spHtml+'</td><td class="num">'+(ok&&r.total_cost!=null?(r.total_cost/1e6).toFixed(3)+'M':'—')+'</td><td class="num">'+cdHtml+'</td><td class="num">'+(r.physical_units!=null?Math.round(r.physical_units)+' &rarr; '+Math.round(r.equiv_units||r.physical_units):'—')+'</td><td>'+redBar+'</td><td class="num">'+(r.overlap_h!=null?fmt(r.overlap_h,1):'—')+'</td><td class="num">'+(r.peak_rss_mb!=null?fmt(r.peak_rss_mb,1):'—')+'</td></tr>';
  });
  th+='</tbody>';
  $('pcm-table').innerHTML=th;
}

// ============ QUALITY ============
function renderQuality(){
  const runs=Object.keys(DATA.qualities).sort();
  $('ql-run').innerHTML=runs.map(function(r){return'<option>'+r+'</option>';}).join('');
  $('ql-run').onchange=function(){updateQualFilters();switchQl();renderQualTables();};
  $('ql-algo').onchange=function(){switchQl();renderQualTables();};
  $('ql-scen').onchange=function(){switchQl();renderQualTables();};
  updateQualFilters();renderQualTables();buildQlViewTabs();
}

function buildQlViewTabs(){
  const views=[{id:'curtailment',label:'Curtailment'},{id:'gap',label:'Gap'},{id:'runtime',label:'Runtime'},{id:'ram',label:'RAM'},{id:'convergence',label:'Convergence'},{id:'bounds',label:'Bounds'}];
  $('ql-view-tabs').innerHTML=views.map(function(v){return'<button class="view-tab'+(v.id===qlActive?' active':'')+'" data-view="'+v.id+'">'+v.label+'</button>';}).join('');
  $('ql-view-tabs').onclick=function(e){const b=e.target.closest('.view-tab');if(!b)return;qlActive=b.dataset.view;document.querySelectorAll('.view-tab').forEach(function(x){x.classList.remove('active');});b.classList.add('active');switchQl();};
  switchQl();
}

function getQlSumRows(){var r=$('ql-run').value,a=$('ql-algo').value,s=$('ql-scen').value;var rows=(DATA.summaries[r]||[]).slice(1);if(a)rows=rows.filter(function(x){return x[0]===a;});if(s)rows=rows.filter(function(x){return x[1]===s;});return rows;}
function getQlItRows(){var r=$('ql-run').value,a=$('ql-algo').value,s=$('ql-scen').value;var rows=(DATA.iterations[r]||[]).slice(1);if(a)rows=rows.filter(function(x){return x[0]===a;});if(s)rows=rows.filter(function(x){return x[1]===s;});return rows;}

function switchQl(){
  const run=$('ql-run')?.value,algo=$('ql-algo')?.value,scen=$('ql-scen')?.value;
  if(qlActive==='curtailment'){
    const rows=(DATA.qualities[run]||[]).slice(1).filter(function(r){return(!algo||r[0]===algo)&&(!scen||r[1]===scen);});
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}
    const layout={height:480,yaxis:{title:'Curtailment (MW)'},barmode:'group'};
    Plotly.newPlot(pl('ql-plot'),[
      {type:'bar',x:rows.map(function(r){return r[0]+'-'+r[1]+'s';}),y:rows.map(function(r){return +r[4];}),name:'Wind Curtailment',marker:{color:'#91cc75'}},
      {type:'bar',x:rows.map(function(r){return r[0]+'-'+r[1]+'s';}),y:rows.map(function(r){return +r[3];}),name:'Load Curtailment',marker:{color:'#ee6666'}}
    ],Object.assign({margin:PLMARGIN,hovermode:'x unified',legend:{orientation:'h',y:-0.2},xaxis:{tickfont:{size:10}},yaxis:{tickfont:{size:10},title:{font:{size:11}}}},layout));
  }else if(qlActive==='gap'){
    const rows=getQlSumRows();
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}
    const g=rows.map(function(r){return +r[6];});
    show('ql-plot',[{type:'bar',x:rows.map(function(r){return r[0]+'-'+r[1]+'s';}),y:g.map(function(x){return Math.max(x,1e-8);}),marker:{color:g.map(function(x){return x<0.01?'#91cc75':x<0.2?'#fac858':'#ee6666';})}}],{yaxis:{title:'Optimality Gap',type:'log'}});
  }else if(qlActive==='runtime'){
    const rows=getQlSumRows();
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}
    show('ql-plot',[{type:'bar',x:rows.map(function(r){return r[0]+'-'+r[1]+'s';}),y:rows.map(function(r){return +r[7];}),marker:{color:rows.map(function(r){return ACOL[r[0]]||'#5470c6';})}}],{yaxis:{title:'Runtime (s)'}});
  }else if(qlActive==='ram'){
    const rows=getQlSumRows();
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No data</div>';return;}
    show('ql-plot',[{type:'bar',x:rows.map(function(r){return r[0]+'-'+r[1]+'s';}),y:rows.map(function(r){return +r[8];}),marker:{color:rows.map(function(r){return ACOL[r[0]]||'#5470c6';})}}],{yaxis:{title:'RAM (MB)'}});
  }else if(qlActive==='convergence'){
    const rows=getQlItRows();
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No iteration data</div>';return;}
    const g={};rows.forEach(function(r){const k=r[0]+'-'+r[1]+'s';if(!g[k])g[k]=[];g[k].push({x:+r[2],y:Math.max(+r[6],1e-8)});});
    const mi=Math.max.apply(null,rows.map(function(r){return +r[2];}));
    const series=Object.entries(g).map(function(e,i){const m={};e[1].forEach(function(p){m[p.x]=p.y;});const d=[];for(var j=1;j<=mi;j++)d.push(m[j]||null);return{x:Array.from({length:mi},function(_,x){return x+1;}),y:d,name:e[0],type:'scatter',mode:'lines+markers',line:{color:C10[i%C10.length]},marker:{size:3}};});
    show('ql-plot',series,{xaxis:{title:'Iteration'},yaxis:{title:'Gap',type:'log'}});
  }else if(qlActive==='bounds'){
    const rows=getQlItRows();
    if(!rows.length){$('ql-plot').innerHTML='<div class="empty-state">No iteration data</div>';return;}
    const mi=Math.max.apply(null,rows.map(function(r){return +r[2];}));
    const g={};rows.forEach(function(r){const k=r[0]+'-'+r[1]+'s';if(!g[k])g[k]={lb:new Array(mi).fill(null),ub:new Array(mi).fill(null)};});
    rows.forEach(function(r){const k=r[0]+'-'+r[1]+'s';g[k].lb[+r[2]-1]=+r[4];g[k].ub[+r[2]-1]=+r[5];});
    const x=Array.from({length:mi},function(_,i){return i+1;});
    const series=[];Object.entries(g).forEach(function(e,i){series.push({x:x,y:e[1].lb,name:e[0]+' LB',type:'scatter',mode:'lines',line:{color:C10[i%C10.length],dash:'dash'}});series.push({x:x,y:e[1].ub,name:e[0]+' UB',type:'scatter',mode:'lines',line:{color:C10[i%C10.length]}});});
    show('ql-plot',series,{xaxis:{title:'Iteration'},yaxis:{title:'Cost'}});
  }
}

function updateQualFilters(){
  const run=$('ql-run').value,rows=DATA.qualities[run];
  if(!rows||rows.length<2)return;
  const algos=Array.from(new Set(rows.slice(1).map(function(r){return r[0];})));
  $('ql-algo').innerHTML='<option value="">All</option>'+algos.map(function(a){return'<option>'+a+'</option>';}).join('');
  const scens=Array.from(new Set(rows.slice(1).map(function(r){return r[1];})));
  $('ql-scen').innerHTML='<option value="">All</option>'+scens.map(function(s){return'<option>'+s+'</option>';}).join('');
}

function renderQualTables(){
  const run=$('ql-run').value,algo=$('ql-algo').value,scen=$('ql-scen').value;
  var qRows=(DATA.qualities[run]||[]).slice(1).filter(function(r){return(!algo||r[0]===algo)&&(!scen||r[1]===scen);});
  var qh='<thead><tr><th>Algorithm</th><th>Scenarios</th><th>Max Balance Error</th><th>Load Curtail</th><th>Wind Curtail</th><th>Peak Load</th></tr></thead><tbody>';
  qRows.forEach(function(r){qh+='<tr><td>'+r[0]+'</td><td>'+r[1]+'</td><td>'+Number(r[2]).toExponential(2)+'</td><td>'+fmt(r[3],3)+'</td><td>'+fmt(r[4],2)+'</td><td>'+fmt(r[5],4)+'</td></tr>';});qh+='</tbody>';$('ql-quality-table').innerHTML=qh;
  var iRows=getQlItRows();
  if(!iRows.length){$('ql-iter-table').innerHTML='<tbody><tr><td class="empty-state" colspan="9">No iteration data</td></tr></tbody>';}
  else{var ih='<thead><tr><th>Algo</th><th>Scen</th><th>Iter</th><th>Active</th><th>Lower Bound</th><th>Upper Bound</th><th>Gap</th><th>Added</th><th>RAM</th></tr></thead><tbody>';
  iRows.forEach(function(r){ih+='<tr><td>'+r[0]+'</td><td>'+r[1]+'</td><td>'+r[2]+'</td><td>'+r[3]+'</td><td>'+fmt(r[4],1)+'</td><td>'+fmt(r[5],1)+'</td><td>'+parseFloat(r[6]).toFixed(5)+'</td><td>'+r[7]+'</td><td>'+r[8]+'</td></tr>';});ih+='</tbody>';$('ql-iter-table').innerHTML=ih;}
}

// ============ SCHEDULE ============
function renderSchedule(){
  const runs=Object.keys(DATA.scheduling).sort();
  $('sc-run').innerHTML=runs.map(function(r){return'<option>'+r+'</option>';}).join('');
  $('sc-run').onchange=updateScAlgo;
  $('sc-algo').onchange=function(){buildScTabs();switchSc();};
  buildScTabs();if(runs.length)updateScAlgo();
}

function updateScAlgo(){const run=$('sc-run').value;const algos=Object.keys(DATA.scheduling[run]||{}).sort();$('sc-algo').innerHTML=algos.map(function(a){return'<option>'+a+'</option>';}).join('');buildScTabs();switchSc();}

function buildScTabs(){
  const run=$('sc-run').value,algo=$('sc-algo').value,sched=(DATA.scheduling[run]||{})[algo]||{};
  const tabs=[];
  if(sched['generator_dispatch'])tabs.push({id:'dispatch',label:'Generator Dispatch'});
  if(sched['unit_commitment_status'])tabs.push({id:'uc_status',label:'UC Status'});
  if(sched['schedule_cost_summary'])tabs.push({id:'cost',label:'Cost Breakdown'});
  if(sched['curtailment_schedule'])tabs.push({id:'curtailment',label:'Curtailment'});
  if(sched['power_balance_summary'])tabs.push({id:'power_bal',label:'Power Balance'});
  if(sched['unit_startup_shutdown_decisions'])tabs.push({id:'startup',label:'Startup/Shutdown'});
  if(sched['schedule_commitment_result'])tabs.push({id:'commit_txt',label:'Commitment Report'});
  if(sched['reserve_schedule'])tabs.push({id:'reserve',label:'Reserves'});
  if(!tabs.length){$('sc-tabs').innerHTML='';return;}
  if(!tabs.find(function(t){return t.id===scActive;}))scActive=tabs[0].id;
  $('sc-tabs').innerHTML=tabs.map(function(t){return'<button class="sched-tab'+(t.id===scActive?' active':'')+'" data-sc="'+t.id+'">'+t.label+'</button>';}).join('');
  $('sc-tabs').onclick=function(e){const b=e.target.closest('.sched-tab');if(!b)return;scActive=b.dataset.sc;document.querySelectorAll('.sched-tab').forEach(function(x){x.classList.remove('active');});b.classList.add('active');switchSc();};
  switchSc();
}

function switchSc(){
  const run=$('sc-run').value,algo=$('sc-algo').value,sched=(DATA.scheduling[run]||{})[algo]||{};
  $('sc-table').innerHTML='';Plotly.purge('sc-plot');

  if(scActive==='dispatch'){
    const rows=sched['generator_dispatch'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No dispatch data</div>';return;}
    const hdr=rows[0],nU=hdr.length-2,byScen={};
    rows.slice(1).forEach(function(r){const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){return r[1];}))).sort(function(a,b){return a-b;});
    const series=[];scens.forEach(function(sc,i){for(var u=0;u<nU;u++){const dash=i===1&&scens.length>1?'dash':'solid';series.push({x:tl,y:byScen[sc].map(function(r){return +r[2+u];}),name:'S'+sc+' Unit '+(u+1),type:'scatter',mode:'lines',line:{color:C10[u%C10.length],dash:dash}});}});
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Dispatch (MW)'}});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){byScen[sc].forEach(function(r){th+='<tr><td>'+sc+'</td>'+r.slice(1).map(function(v){return'<td>'+fmt(v,4)+'</td>';}).join('')+'</tr>';});});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='uc_status'){
    const rows=sched['unit_commitment_status'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No UC data</div>';return;}
    const hdr=rows[0],dr=rows.slice(1),nU=hdr.length-1,tl=dr.map(function(r){return r[0];});
    const series=[];for(var u=0;u<nU;u++){series.push({x:tl,y:dr.map(function(r){return Math.round(+r[1+u]);}),name:'Unit '+(u+1),type:'bar',marker:{color:C10[u%C10.length]}});}
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Commitment',range:[0,nU+0.5],dtick:1},barmode:'stack'});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){th+='<tr>'+r.map(function(v){return'<td>'+fmt(v,3)+'</td>';}).join('')+'</tr>';});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='cost'){
    const rows=sched['schedule_cost_summary'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No cost data</div>';return;}
    const others=rows.slice(1).filter(function(r){return +r[1]!==0&&r[0]!=='total_cost';});
    const total=rows.slice(1).find(function(r){return r[0]==='total_cost';});
    $('sc-plot').innerHTML='<div class="cost-grid"><div id="sc-pie" class="plot-div"></div><div id="sc-bar" class="plot-div"></div></div>';
    const names=others.map(function(r){return r[0].replace(/_/g,' ').replace(/cost/g,'');});
    Plotly.newPlot('sc-pie',[{type:'pie',labels:names,values:others.map(function(r){return +r[1];}),marker:{colors:C10},textinfo:'label+percent',textfont:{size:10}}],{height:480,margin:{l:10,r:10,t:10,b:10}},PLCFG);
    Plotly.newPlot('sc-bar',[{type:'bar',y:others.map(function(r){return r[0];}),x:others.map(function(r){return +r[1];}),orientation:'h',marker:{color:others.map(function(_,i){return C10[i%C10.length];})}}],{height:480,margin:{l:140,r:15,t:10,b:30},xaxis:{title:'Cost'}},PLCFG);
    var th='<thead><tr><th>Component</th><th>Value</th></tr></thead><tbody>';
    if(total)th+='<tr><td><strong>'+total[0]+'</strong></td><td><strong>'+fmt(total[1],2)+'</strong></td></tr>';
    others.forEach(function(r){th+='<tr><td>'+r[0]+'</td><td>'+fmt(r[1],2)+'</td></tr>';});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='curtailment'){
    const rows=sched['curtailment_schedule'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No curtailment data</div>';return;}
    const hdr=rows[0],byScen={};rows.slice(1).forEach(function(r){const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){return r[1];}))).sort(function(a,b){return a-b;});
    const series=[];for(var c=2;c<hdr.length;c++){series.push({x:tl,y:tl.map(function(t){const rs=byScen[scens[0]];const r=rs?rs.find(function(rr){return rr[1]===String(t);}):null;return r?+r[c]:0;}),name:hdr[c],type:'scatter',mode:'lines',fill:'tozeroy',line:{color:C10[(c-2)%C10.length]},fillcolor:C10[(c-2)%C10.length]+'22'});}
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Curtailment (MW)'}});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){byScen[sc].forEach(function(r){th+='<tr>'+r.map(function(v){return'<td>'+fmt(v,4)+'</td>';}).join('')+'</tr>';});});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='power_bal'){
    const rows=sched['power_balance_summary'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No power balance data</div>';return;}
    const hdr=rows[0],byScen={};rows.slice(1).forEach(function(r){const s=r[0];if(!byScen[s])byScen[s]=[];byScen[s].push(r);});
    const scens=Object.keys(byScen).sort();
    const tl=Array.from(new Set(rows.slice(1).map(function(r){return r[1];}))).sort(function(a,b){return a-b;});
    const keys=[2,3,4];const labels=['Thermal','Served Load','DataCenter Load'];
    const series=keys.map(function(k,i){return{x:tl,y:tl.map(function(t){const rs=byScen[scens[0]];const r=rs?rs.find(function(rr){return rr[1]===String(t);}):null;return r?+r[k]:null;}),name:labels[i],type:'scatter',mode:'lines',line:{color:C10[i]}};});
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Power (MW)'}});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    scens.forEach(function(sc){byScen[sc].forEach(function(r){th+='<tr>'+r.map(function(v){return'<td>'+fmt(v,4)+'</td>';}).join('')+'</tr>';});});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='startup'){
    const rows=sched['unit_startup_shutdown_decisions'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No startup data</div>';return;}
    const hdr=rows[0],dr=rows.slice(1),tl=dr.map(function(r){return r[0];}),nU=Math.floor((hdr.length-1)/2);
    const series=[];for(var u=0;u<nU;u++){series.push({x:tl,y:dr.map(function(r){return +r[1+u];}),name:'Unit '+(u+1)+' Start',type:'bar',marker:{color:'#91cc75'}});series.push({x:tl,y:dr.map(function(r){return -Math.abs(+r[1+nU+u]);}),name:'Unit '+(u+1)+' Stop',type:'bar',marker:{color:'#ee6666'}});}
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Decision',range:[-1.5,1.5],dtick:1},barmode:'stack'});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){th+='<tr>'+r.map(function(v){return'<td>'+fmt(v,2)+'</td>';}).join('')+'</tr>';});th+='</tbody>';$('sc-table').innerHTML=th;
  }else if(scActive==='commit_txt'){
    var txt=sched['schedule_commitment_result']||'';for(const k of Object.keys(sched)){if(k.endsWith('_schedule_commitment_result')){txt=sched[k];break;}}
    $('sc-plot').innerHTML='<pre class="short">'+escapeHTML(txt||'No commitment report available')+'</pre>';$('sc-table').innerHTML='';
  }else if(scActive==='reserve'){
    const rows=sched['reserve_schedule'];if(!rows||rows.length<2){$('sc-plot').innerHTML='<div class="empty-state">No reserve data</div>';return;}
    const hdr=rows[0],dr=rows.slice(1);
    const units=Array.from(new Set(dr.map(function(r){return r[1];}))).sort();
    const tl=Array.from(new Set(dr.map(function(r){return r[2];}))).sort(function(a,b){return a-b;});
    const series=[];units.forEach(function(u,i){const d=dr.filter(function(r){return r[1]===u;});
      series.push({x:tl,y:tl.map(function(t){const r=d.find(function(rr){return rr[2]===String(t);});return r?+r[3]:null;}),name:'Unit '+u+' Up',type:'scatter',mode:'lines',line:{color:C10[(i*2)%C10.length]}});
      series.push({x:tl,y:tl.map(function(t){const r=d.find(function(rr){return rr[2]===String(t);});return r?+r[4]:null;}),name:'Unit '+u+' Down',type:'scatter',mode:'lines',line:{color:C10[(i*2+1)%C10.length],dash:'dash'}});
    });
    show('sc-plot',series,{xaxis:{title:'Time (h)'},yaxis:{title:'Reserve (MW)'}});
    var th='<thead><tr>'+hdr.map(function(h){return'<th>'+h+'</th>';}).join('')+'</tr></thead><tbody>';
    dr.forEach(function(r){th+='<tr>'+r.map(function(v){return'<td>'+fmt(v,4)+'</td>';}).join('')+'</tr>';});th+='</tbody>';$('sc-table').innerHTML=th;
  }
}

// ============ REPORTS ============
function renderReports(){
  const runs=Object.keys(DATA.reports).sort();
  $('rp-run').innerHTML=runs.map(function(r){return'<option>'+r+'</option>';}).join('');
  $('rp-run').onchange=updateRp;
  const svgRuns=Object.keys(DATA.svgs).filter(function(r){return Object.keys(DATA.svgs[r]).length;}).sort();
  $('svg-run').innerHTML=svgRuns.map(function(r){return'<option>'+r+'</option>';}).join('');
  $('svg-run').onchange=updateSvgCharts;
  $('svg-zoom-out').onclick=function(){setSvgZoom(Math.max(.5,svgZoom-.15));};
  $('svg-zoom-reset').onclick=function(){setSvgZoom(1);};
  $('svg-zoom-in').onclick=function(){setSvgZoom(Math.min(2.5,svgZoom+.15));};
  if(runs.length)updateRp();if(svgRuns.length)updateSvgCharts();
}

function updateRp(){const r=$('rp-run').value;const h=DATA.reports[r]||'';$('rp-content').innerHTML=h||'<div class="empty-state">No report</div>';}

function updateSvgCharts(){
  const r=$('svg-run').value;
  const charts=Object.keys(DATA.svgs[r]||{}).sort();
  if(!charts.length){activeSvgChart='';$('svg-chart-tabs').innerHTML='';updateSvgDisplay();return;}
  if(!activeSvgChart||charts.indexOf(activeSvgChart)<0)activeSvgChart=charts[0];
  $('svg-chart-tabs').innerHTML=charts.map(function(c){return'<button class="chart-tab'+(c===activeSvgChart?' active':'')+'" data-chart="'+escapeHTML(c)+'">'+formatChartLabel(c)+'</button>';}).join('');
  $('svg-chart-tabs').onclick=function(e){const b=e.target.closest('.chart-tab');if(!b)return;activeSvgChart=b.dataset.chart;document.querySelectorAll('.chart-tab').forEach(function(x){x.classList.remove('active');});b.classList.add('active');setSvgZoom(1);updateSvgDisplay();};
  updateSvgDisplay();
}

function updateSvgDisplay(){
  const r=$('svg-run').value,c=activeSvgChart,b64=(DATA.svgs[r]||{})[c];
  if(!b64){$('svg-display').innerHTML='<div class="empty-state">No SVG</div>';applyReportTheme();return;}
  $('svg-display').innerHTML='<div class="report-svg-stage">'+atob(b64)+'</div>';
  const svg=$('svg-display').querySelector('svg');
  if(svg){svg.setAttribute('role','img');svg.setAttribute('aria-label',formatChartLabel(c));if(!svg.querySelector('title')){const title=document.createElementNS('http://www.w3.org/2000/svg','title');title.textContent=formatChartLabel(c);svg.prepend(title);}}
  attachSvgInteractions();
  setSvgZoom(svgZoom);
  applyReportTheme();
}

function formatChartLabel(c){return String(c||'Chart').replace(/_/g,' ').replace(/\\b\\w/g,function(m){return m.toUpperCase();});}

function setSvgZoom(z){
  svgZoom=z;
  const stage=$('svg-display')?$('svg-display').querySelector('.report-svg-stage'):null;
  if(stage)stage.style.transform='scale('+svgZoom+')';
  const reset=$('svg-zoom-reset');
  if(reset)reset.textContent=svgZoom.toFixed(1)+'x';
}

function attachSvgInteractions(){
  const svg=$('svg-display')?$('svg-display').querySelector('svg'):null;
  if(!svg)return;
  svg.querySelectorAll('rect,polyline,line,path,circle,text').forEach(function(el,i){
    el.classList.add('svg-hotspot');
    if(!el.querySelector('title')){const t=document.createElementNS('http://www.w3.org/2000/svg','title');t.textContent=(el.textContent||el.getAttribute('aria-label')||formatChartLabel(activeSvgChart)||'Chart item').trim();el.appendChild(t);}
    el.addEventListener('click',function(ev){ev.stopPropagation();svg.querySelectorAll('.svg-selected').forEach(function(x){x.classList.remove('svg-selected');});el.classList.add('svg-selected');});
  });
  svg.addEventListener('click',function(){svg.querySelectorAll('.svg-selected').forEach(function(x){x.classList.remove('svg-selected');});});
}

function applyReportTheme(){
  const wrap=$('svg-display');
  if(!wrap)return;
  const dark=isDarkTheme();
  wrap.classList.toggle('dark-chart',dark);
  const svg=wrap.querySelector('svg');
  if(!svg)return;
  const bg=dark?'#2a2a2a':'#ffffff';
  const text=dark?'#f8fafc':'#1e293b';
  const muted=dark?'#b0b0b0':'#333333';
  svg.style.background=bg;
  svg.querySelectorAll('rect').forEach(function(el,i){const fill=(el.getAttribute('fill')||'').toLowerCase();if(i===0||fill==='white'||fill==='#fff'||fill==='#ffffff')el.setAttribute('fill',bg);});
  svg.querySelectorAll('text').forEach(function(el){el.setAttribute('fill',text);});
  svg.querySelectorAll('line').forEach(function(el){el.setAttribute('stroke',muted);});
}

// ============ SETTINGS ============
function renderSettings(){
  const cfg=DATA.config;if(!cfg||!cfg.sections)return;
  const lm={boundary:'Boundary',common:'Common',model:'Model',benders:'Benders','benders.cuts':'Benders \\u2014 Cuts','benders.subproblems':'Benders \\u2014 Subproblems',ccg:'CCG',dro:'DRO',frequency:'Frequency',test:'Test'};
  const bySec={};cfg.sections.forEach(function(sec){bySec[sec.name]=sec.fields||[];});
  const inputSections=collectSections(cfg.sections,function(sec,f){return classifySetting(sec.name,f)==='input';});
  const testSections=collectSections(cfg.sections,function(sec,f){return classifySetting(sec.name,f)==='testing';});
  const modelLinearKeys=['MODEL_IS_PIECE_LINEAR','MODEL_NUM_SEGMENTS','MODEL_ALPHA','MODEL_BETA'];
  const modelLinear=collectSections(cfg.sections,function(sec,f){return modelLinearKeys.indexOf(f.key)>=0;});
  const modelFrequency=collectSections(cfg.sections,function(sec,f){return String(sec.name).toLowerCase()==='frequency';});
  const modelBase=collectSections(cfg.sections,function(sec,f){return classifySetting(sec.name,f)==='model'&&modelLinearKeys.indexOf(f.key)<0&&String(sec.name).toLowerCase()!=='frequency';});
  const bendersSections=['benders','benders.cuts','benders.subproblems'].map(function(name){return{name:name,fields:bySec[name]||[]};}).filter(function(sec){return sec.fields.length;});
  const ccgSections=['ccg','dro'].map(function(name){return{name:name,fields:bySec[name]||[]};}).filter(function(sec){return sec.fields.length;});

  var html='';
  html+=settingsCard('algorithm','Algorithm Settings','Solvers, decomposition controls, convergence tolerances, cuts, and iteration policies.',
    'Algorithm Mode','settings-algorithm-mode',[['benders','Benders'],['ccg','CCG']],[
      panelHtml('benders',bendersSections,'Benders-specific relaxation, cut, and subproblem parameters.'),
      panelHtml('ccg',ccgSections,'Column-and-constraint generation master/recourse and DRO parameters.')
    ]);
  html+=settingsCard('input','Input Settings','Input source presets and boundary/data loading controls.',
    'Data Source','settings-data-source',[['excel','Custom Excel'],['ieee118','Built-in IEEE 118 Case'],['ieee14','Built-in IEEE 14 Case']],[
      panelHtml('excel',inputSections,'Custom data source and boundary import controls.'),
      panelNote('ieee118','Built-in IEEE 118 benchmark selected. Custom Excel path controls are hidden but kept in the saved configuration.'),
      panelNote('ieee14','Built-in IEEE 14 benchmark selected. Use this lightweight case for fast validation runs.')
    ]);
  html+=settingsCard('model','Model Settings','Network topology, constraint architecture, relaxation coefficients, BESS, and frequency model parameters.',
    'Network topology / constraint architecture','settings-model-formulation',[['dc','DC-OPF (DC power flow)'],['ac','AC-OPF (AC power flow)'],['linearized','Grid Linearization (linearized network)']],[
      panelHtml('dc',modelBase,'DC-OPF and system-level model switches.'),
      panelHtml('ac',modelFrequency,'AC-OPF placeholder mapped to frequency/security related controls available in this project.'),
      panelHtml('linearized',modelLinear,'Piecewise and grid linearization parameters.')
    ]);
  html+=settingsCard('testing','Testing Settings','Benchmark cases, scenario mode, deterministic/stochastic validation, and test harness options.',
    'Testing Mode','settings-testing-mode',[['deterministic','Deterministic Validation'],['stochastic','Stochastic Scenario Test'],['reduction','Scenario Reduction']],[
      panelHtml('deterministic',testSections,'Deterministic test harness and local project activation settings.'),
      panelNote('stochastic','Stochastic scenario count and algorithm iteration controls are managed in Algorithm Settings for Benders/CCG.'),
      panelNote('reduction','Scenario reduction mode is a UI preset; add project-specific reduction keys to runtime_config.toml to expose editable fields here.')
    ]);
  $('settings-grid').innerHTML=html;
  bindSettingSelects();
}

function classifySetting(sectionName,f){
  const sec=String(sectionName||'').toLowerCase();
  const key=String(f.key||'').toUpperCase();
  if(sec==='test'||key.indexOf('TEST')>=0||key.indexOf('BENCHMARK')>=0||key.indexOf('IEEE')>=0||key.indexOf('CASE')>=0)return'testing';
  if(sec==='boundary'||key.indexOf('PATH')>=0||key.indexOf('EXCEL')>=0||key.indexOf('SOURCE')>=0||key.indexOf('INPUT')>=0||key.indexOf('SAMPLE')>=0||key.indexOf('LOAD')>=0)return'input';
  if(sec==='model'||sec==='frequency'||key.indexOf('MODEL_')===0||key.indexOf('FREQUENCY_')===0||key.indexOf('NETWORK')>=0||key.indexOf('SYSTEM')>=0||key.indexOf('THERMAL')>=0||key.indexOf('WIND')>=0||key.indexOf('BESS')>=0||key.indexOf('COEFFICIENT')>=0||key.indexOf('BASE')>=0)return'model';
  return'algorithm';
}

function settingFieldHtml(f){
  const id='cfg-'+f.key;
  if(f.type==='bool')return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="checkbox" id="'+id+'" data-key="'+f.key+'" '+(f.value?'checked':'')+'></div>';
  if(f.type==='number'||f.type==='float'||f.type==='integer')return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="number" id="'+id+'" data-key="'+f.key+'" value="'+f.value+'" step="any"></div>';
  return'<div class="field"><label for="'+id+'">'+f.key+'</label><input type="text" id="'+id+'" data-key="'+f.key+'" value="'+escapeHtml(String(f.value))+'"></div>';
}

function collectSections(sections,predicate){
  return sections.map(function(sec){return{name:sec.name,fields:(sec.fields||[]).filter(function(f){return predicate(sec,f);})};}).filter(function(sec){return sec.fields.length;});
}

function settingsCard(id,title,note,controlLabel,selectId,options,panels){
  return '<fieldset class="settings-category settings-'+id+'"><legend>'+title+'</legend><div class="category-note">'+note+'</div><div class="setting-control"><label for="'+selectId+'">'+controlLabel+'</label><select id="'+selectId+'" data-setting-router="'+id+'">'+options.map(function(o){return'<option value="'+o[0]+'">'+o[1]+'</option>';}).join('')+'</select></div><div class="setting-panels" data-setting-panels="'+id+'">'+panels.join('')+'</div></fieldset>';
}

function panelHtml(value,sections,note){
  var body=sections.length?sections.map(renderSettingsSection).join(''):'<div class="setting-panel-note">No editable fields are currently mapped to this mode.</div>';
  return '<div class="setting-panel sf-hidden" data-panel="'+value+'"><div class="setting-panel-note">'+note+'</div>'+body+'</div>';
}

function panelNote(value,note){
  return '<div class="setting-panel sf-hidden" data-panel="'+value+'"><div class="setting-panel-note">'+note+'</div></div>';
}

function renderSettingsSection(sec){
  const lm={boundary:'Boundary',common:'Common',model:'Model',benders:'Benders','benders.cuts':'Benders \\u2014 Cuts','benders.subproblems':'Benders \\u2014 Subproblems',ccg:'CCG',dro:'DRO',frequency:'Frequency',test:'Test'};
  return '<div class="settings-section"><h3>'+(lm[sec.name]||sec.name)+'</h3><div class="fields">'+sec.fields.map(settingFieldHtml).join('')+'</div></div>';
}

function bindSettingSelects(){
  document.querySelectorAll('[data-setting-router]').forEach(function(sel){
    function sync(){
      const group=sel.dataset.settingRouter;
      document.querySelectorAll('[data-setting-panels="'+group+'"] .setting-panel').forEach(function(panel){const active=panel.dataset.panel===sel.value;panel.classList.toggle('active',active);panel.classList.toggle('sf-hidden',!active);});
    }
    sel.onchange=sync;
    sync();
  });
}

function escapeHtml(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}

async function saveConfig(){
  const btn=$('save-config-btn'),msg=$('save-msg');btn.disabled=true;msg.className='msg';msg.textContent='Saving...';
  const u={};let invalid=null;document.querySelectorAll('[data-key]').forEach(function(el){const k=el.dataset.key;if(el.type==='checkbox')u[k]=el.checked;else if(el.type==='number'){const v=Number(el.value);if(el.value===''||Number.isNaN(v))invalid=k;else u[k]=v;}else u[k]=el.value;});
  if(invalid){msg.className='msg err';msg.textContent='Invalid numeric value: '+invalid;btn.disabled=false;return;}
  try{const r=await apiFetch('/api/config',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(u)});if(r.ok){msg.className='msg ok';msg.textContent='Saved.';}else{let detail='';try{const err=await r.json();detail=err.error?': '+err.error:'';}catch(e){}msg.className='msg err';msg.textContent='Save failed: '+r.status+detail;}}catch(e){msg.className='msg err';msg.textContent='Save failed - server running?';}
  btn.disabled=false;setTimeout(function(){msg.textContent='';},3000);
}
/* __RUN_JS__ */

try{init();}catch(e){document.body.innerHTML='<div style="padding:40px;color:#dc2626;font-family:monospace;"><h2>Error</h2><pre>'+e.message+'</pre><pre>'+e.stack+'</pre></div>';}