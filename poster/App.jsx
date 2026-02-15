import React from 'react';
import {
  ComposedChart,
  LineChart,
  Line,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

// --------------------
// Data (from manuscript tables)
// --------------------

// Total incidents (primary definition: Alone / Group / Observed)
const totalPrimary = [
  { age: 'Under 12', Alone: 47.6, Group: 27.5, Observed: 25.0 },
  { age: '12–14', Alone: 42.9, Group: 24.8, Observed: 32.2 },
  { age: '15–17', Alone: 42.7, Group: 32.6, Observed: 24.7 },
  { age: '18–20', Alone: 46.4, Group: 33.2, Observed: 20.4 },
  { age: '21–29', Alone: 57.3, Group: 21.1, Observed: 21.5 },
  { age: '30+', Alone: 64.7, Group: 12.0, Observed: 23.2 },
].map(d => ({ ...d, Social: +(d.Group + d.Observed).toFixed(1) }));

// Theft incidents (primary definition)
const theftPrimary = [
  { age: 'Under 12', Alone: 48.2, Group: 32.5, Observed: 19.3 },
  { age: '12–14', Alone: 42.3, Group: 31.6, Observed: 26.1 },
  { age: '15–17', Alone: 44.8, Group: 34.3, Observed: 20.9 },
  { age: '18–20', Alone: 46.1, Group: 33.2, Observed: 20.7 },
  { age: '21–29', Alone: 52.7, Group: 24.1, Observed: 23.2 },
  { age: '30+', Alone: 60.6, Group: 17.4, Observed: 22.0 },
].map(d => ({ ...d, Social: +(d.Group + d.Observed).toFixed(1) }));

// Violent incidents (primary definition)
const violentPrimary = [
  { age: 'Under 12', Alone: 47.3, Group: 25.7, Observed: 26.9 },
  { age: '12–14', Alone: 43.1, Group: 23.5, Observed: 33.5 },
  { age: '15–17', Alone: 42.0, Group: 32.0, Observed: 26.0 },
  { age: '18–20', Alone: 46.6, Group: 33.2, Observed: 20.2 },
  { age: '21–29', Alone: 59.0, Group: 20.0, Observed: 20.9 },
  { age: '30+', Alone: 65.8, Group: 10.7, Observed: 23.5 },
].map(d => ({ ...d, Social: +(d.Group + d.Observed).toFixed(1) }));

// --------------------
// Logistic regression (key telling comparisons; Total; ref = 15–17)
// --------------------

const totalLogitKey = [
  { group: '18–20', or: 1.16, low: 0.98, high: 1.37 },
  { group: '30+', or: 2.46, low: 2.11, high: 2.87 },
];

// --------------------
// Styling helpers
// --------------------

const H = ({ children }) => (
  <div className="bg-[#4a4a4a] text-white py-1 px-3 mb-3 rounded-sm uppercase tracking-wider font-bold text-sm">
    {children}
  </div>
);

const Panel = ({ title, children }) => (
  <div className="bg-white border border-gray-200 rounded shadow-sm">
    <div className="px-4 py-2 border-b border-gray-200">
      <div className="text-xs font-extrabold uppercase tracking-wider text-[#9d2235]">{title}</div>
    </div>
    <div className="p-4">{children}</div>
  </div>
);

const BigNumber = ({ value, label, sub }) => (
  <div className="text-center p-3 border-2 border-[#9d2235] rounded-lg">
    <div className="text-4xl font-black text-[#9d2235] leading-none">{value}</div>
    <div className="text-[11px] font-bold uppercase mt-1">{label}</div>
    {sub ? <div className="text-[10px] text-gray-500 mt-1">{sub}</div> : null}
  </div>
);

const SocialFigure = ({ data, title }) => (
  <div>
    <div className="text-[11px] font-bold uppercase text-gray-500 mb-2 text-center">{title}</div>
    <div className="h-72">
      <ResponsiveContainer width="100%" height="100%">
        <ComposedChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} />
          <XAxis dataKey="age" tick={{ fontSize: 10 }} />
          <YAxis domain={[0, 100]} tick={{ fontSize: 10 }} />
          <Tooltip contentStyle={{ fontSize: '10px' }} />
          <Legend wrapperStyle={{ fontSize: '10px', paddingTop: '10px' }} />

          {/* stacked bars */}
          <Bar dataKey="Alone" stackId="a" fill="#d1d5db" name="Alone" />
          <Bar dataKey="Observed" stackId="a" fill="#6b7280" name="Observed" />
          <Bar dataKey="Group" stackId="a" fill="#9d2235" name="Co-offending (Group)" />

          {/* Social line (headline construct) */}
          <Line type="monotone" dataKey="Social" stroke="#111827" strokeWidth={2.5} dot={{ r: 3 }} name="Social (Group+Observed)" />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  </div>
);

const SmallSocialLine = ({ data, title }) => (
  <div className="bg-white border border-gray-200 rounded p-3">
    <div className="text-[10px] font-extrabold uppercase text-gray-600 mb-2">{title}</div>
    <div className="h-36">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} />
          <XAxis dataKey="age" tick={{ fontSize: 9 }} />
          <YAxis domain={[30, 70]} tick={{ fontSize: 9 }} />
          <Tooltip contentStyle={{ fontSize: '10px' }} />
          <Line type="monotone" dataKey="Social" stroke="#9d2235" strokeWidth={2} dot={{ r: 2 }} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  </div>
);

const ForestPlot = ({ data, title, min = 0.5, max = 3.0 }) => {
  const pct = (x) => ((x - min) / (max - min)) * 100;
  return (
    <div className="bg-white border border-gray-200 rounded p-3">
      <div className="text-[10px] font-extrabold uppercase text-gray-600 mb-2">{title}</div>

      {/* scale */}
      <div className="relative h-6 mb-2">
        <div className="absolute left-0 right-0 top-1/2 -translate-y-1/2 h-[2px] bg-gray-200" />
        {/* reference line at OR=1 */}
        <div
          className="absolute top-0 bottom-0 w-[2px] bg-[#9d2235]"
          style={{ left: `${pct(1)}%` }}
          title="OR = 1"
        />
        <div className="absolute -bottom-3 left-0 text-[9px] text-gray-400">{min}</div>
        <div className="absolute -bottom-3 left-1/2 -translate-x-1/2 text-[9px] text-gray-400">1</div>
        <div className="absolute -bottom-3 right-0 text-[9px] text-gray-400">{max}</div>
      </div>

      <div className="space-y-3">
        {data.map((d) => (
          <div key={d.group} className="grid grid-cols-[52px_1fr] items-center gap-2">
            <div className="text-[10px] font-bold text-gray-700">{d.group}</div>
            <div className="relative h-4">
              {/* CI */}
              <div
                className="absolute top-1/2 -translate-y-1/2 h-[2px] bg-gray-700"
                style={{ left: `${pct(d.low)}%`, width: `${pct(d.high) - pct(d.low)}%` }}
              />
              {/* point */}
              <div
                className="absolute top-1/2 -translate-y-1/2 h-[8px] w-[8px] rounded-full bg-gray-900"
                style={{ left: `calc(${pct(d.or)}% - 4px)` }}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="text-[9px] text-gray-500 mt-2">
        ORs (with 95% CIs) from survey-weighted logistic regression (Total; ref = 15–17).
      </div>
    </div>
  );
};

// --------------------
// Pages
// --------------------

const Page1 = () => (
  <div className="bg-white shadow-2xl w-full max-w-[1200px] border border-gray-300 flex flex-col p-6">
    {/* Header */}
    <div className="flex justify-between items-start border-b-4 border-[#9d2235] pb-4 mb-6">
      <div>
        <h1 className="text-2xl font-black text-[#9d2235] leading-tight uppercase">
          Social context of incidents across age: NCVS survey-weighted analyses (2014–2022)
        </h1>
        <p className="text-lg font-bold text-gray-700 mt-1">Danny Zweben | Temple University</p>
      </div>
      <div className="text-right">
        <div className="bg-[#4a4a4a] text-white px-4 py-2 font-bold rounded">CAB LAB</div>
        <p className="text-xs mt-1 text-gray-500 font-semibold uppercase tracking-widest">Cognitive & Behavioral Lab</p>
      </div>
    </div>

    <div className="grid grid-cols-12 gap-6 flex-grow">
      {/* Left column */}
      <div className="col-span-4 flex flex-col gap-6">
        <div className="bg-gray-50 p-4 border-l-4 border-[#9d2235] rounded-r">
          <H>Primary question</H>
          <p className="text-sm font-semibold text-gray-900 leading-relaxed">
            Are incidents more likely to occur in a <span className="font-bold">social context</span> during adolescence than adulthood?
          </p>
          <p className="text-xs text-gray-700 mt-2">
            <span className="font-bold">Secondary:</span> Do ages <span className="font-bold">18–20</span> resemble teens (15–17) or older adults?
          </p>
        </div>

        <Panel title="Data & approach (brief)">
          <ul className="list-disc ml-4 text-xs space-y-2 text-gray-700">
            <li><span className="font-bold">Data:</span> NCVS 2014–2022; incident-level records.</li>
            <li><span className="font-bold">Scopes:</span> Total; Theft/property; Violent/nonfatal personal.</li>
            <li><span className="font-bold">Primary social context:</span> Social = Co-offending + Observed vs Alone.</li>
            <li><span className="font-bold">Observed:</span> derived category for solo incidents with others present who did not help.</li>
            <li><span className="font-bold">Inference:</span> survey weights + replicate weights (Fay BRR); Rao–Scott + planned Bonferroni pairwise; survey-weighted logistic regression.</li>
          </ul>
        </Panel>

        <Panel title="Key planned contrasts (Total; primary)">
          <ul className="list-disc ml-4 text-xs space-y-2 text-gray-700">
            <li>15–17 vs 18–20: adj p = 1.00 (ns), Δ = 3.7 points (Social).</li>
            <li>15–17 vs 21–29: adj p &lt; .001, Δ = 14.6 points.</li>
            <li>15–17 vs 30+: adj p &lt; .001, Δ = 22.0 points.</li>
          </ul>
        </Panel>
      </div>

      {/* Middle column */}
      <div className="col-span-5">
        <H>Results (Total incidents; primary definition)</H>
        <SocialFigure data={totalPrimary} title="Social context distribution (%) with Social = Group + Observed" />
      </div>

      {/* Right column */}
      <div className="col-span-3 flex flex-col gap-6">
        <Panel title="Effect-size headline (Total; primary)">
          <BigNumber value="Δ = +22.0" label="Social (15–17) − Social (30+)" sub="57.3% vs 35.3%" />
        </Panel>

        <Panel title="Logistic regression (key comparisons)">
          <div className="text-xs text-gray-700 leading-relaxed mb-3">
            Odds ratios for <span className="font-bold">solo offending</span> (Total; ref = 15–17).
          </div>
          <ForestPlot data={totalLogitKey} title="Telling comparisons" />
        </Panel>

        <Panel title="Takeaways">
          <ul className="list-disc ml-4 text-xs space-y-2 text-gray-700">
            <li>Social involvement is higher in adolescence and ages 18–20 than in adulthood.</li>
            <li>Teen–adult differences are large in magnitude (Δ points) across outcomes.</li>
          </ul>
        </Panel>
      </div>
    </div>

    <div className="mt-6 pt-4 border-t-4 border-[#9d2235] flex justify-between items-center">
      <p className="text-xs font-bold text-gray-600 uppercase">NCVS incident analyses (survey-weighted)</p>
      <div className="text-gray-400 text-xs">CABLAB</div>
    </div>
  </div>
);

const Page2 = () => (
  <div className="bg-white shadow-2xl w-full max-w-[1200px] border border-gray-300 flex flex-col p-6">
    <div className="flex justify-between items-start border-b-4 border-[#9d2235] pb-4 mb-6">
      <div>
        <h2 className="text-xl font-black text-[#9d2235] leading-tight uppercase">Replication across scopes</h2>
        <p className="text-sm font-semibold text-gray-700 mt-1">(Poster page 2)</p>
      </div>
      <div className="text-right">
        <div className="bg-[#4a4a4a] text-white px-4 py-2 font-bold rounded">CAB LAB</div>
      </div>
    </div>

    <div className="grid grid-cols-12 gap-6 flex-grow">
      <div className="col-span-7">
        <H>Social (%) by age (primary definition)</H>
        <div className="grid grid-cols-1 gap-3">
          <SmallSocialLine data={totalPrimary} title="Total incidents" />
          <SmallSocialLine data={theftPrimary} title="Theft/property incidents" />
          <SmallSocialLine data={violentPrimary} title="Violent/nonfatal personal incidents" />
        </div>
      </div>

      <div className="col-span-5 flex flex-col gap-6">
        <Panel title="Key teen–adult contrasts (Δ points)">
          <div className="text-xs text-gray-700 mb-3">
            Effect magnitudes (percentage-point differences) for Social (Group+Observed).
          </div>
          <div className="grid grid-cols-1 gap-3">
            <BigNumber value="Δ = +22.0" label="Total: 15–17 vs 30+" sub="Bonferroni: p &lt; .001" />
            <BigNumber value="Δ = +15.8" label="Theft: 15–17 vs 30+" sub="Bonferroni: p &lt; .001" />
            <BigNumber value="Δ = +23.8" label="Violent: 15–17 vs 30+" sub="Bonferroni: p &lt; .001" />
          </div>
        </Panel>

        <Panel title="Conventional check">
          <div className="text-xs text-gray-700 leading-relaxed">
            Results were consistent when defining sociality as <span className="font-bold">co-offending only</span> (group vs alone).
          </div>
        </Panel>
      </div>
    </div>

    <div className="mt-6 pt-4 border-t-4 border-[#9d2235] flex justify-between items-center">
      <p className="text-xs font-bold text-gray-600 uppercase">NCVS incident analyses (survey-weighted)</p>
      <div className="text-gray-400 text-xs">CABLAB</div>
    </div>
  </div>
);

const Page3 = () => (
  <div className="bg-white shadow-2xl w-full max-w-[1200px] border border-gray-300 flex flex-col p-6">
    <div className="flex justify-between items-start border-b-4 border-[#9d2235] pb-4 mb-6">
      <div>
        <h2 className="text-xl font-black text-[#9d2235] leading-tight uppercase">Overall pattern (what it means)</h2>
        <p className="text-sm font-semibold text-gray-700 mt-1">(Poster page 3)</p>
      </div>
      <div className="text-right">
        <div className="bg-[#4a4a4a] text-white px-4 py-2 font-bold rounded">CAB LAB</div>
      </div>
    </div>

    <div className="grid grid-cols-12 gap-6 flex-grow">
      <div className="col-span-7">
        <H>Overarching results</H>
        <div className="grid grid-cols-1 gap-4">
          <Panel title="Summary">
            <div className="text-sm text-gray-800 leading-relaxed">
              Across the NCVS incident data, incidents in adolescence and ages 18–20 are more likely to occur in a
              <span className="font-bold"> social context</span> (co-offending and/or observed) than in adulthood.
            </div>
          </Panel>

          <Panel title="How to read “Social”">
            <ul className="list-disc ml-4 text-xs space-y-2 text-gray-700">
              <li><span className="font-bold">Social</span> = <span className="font-bold">Group</span> (co-offending) + <span className="font-bold">Observed</span>.</li>
              <li><span className="font-bold">Observed</span> is our derived category for solo incidents with others present who did not help.</li>
              <li>Poster emphasis: <span className="font-bold">Δ points</span> and interval/model checks, not omnibus tests.</li>
            </ul>
          </Panel>
        </div>
      </div>

      <div className="col-span-5 flex flex-col gap-6">
        <Panel title="Three takeaways (poster-friendly)">
          <ul className="list-disc ml-4 text-xs space-y-3 text-gray-700">
            <li><span className="font-bold">Teen vs adult differences are large:</span> Total Δ(15–17 vs 30+) = +22.0 points.</li>
            <li><span className="font-bold">Adjacency check:</span> 15–17 vs 18–20 differences are small relative to teen–adult gaps.</li>
            <li><span className="font-bold">Robustness:</span> the pattern persists under co-offending-only sociality.</li>
          </ul>
        </Panel>

        <Panel title="Key numbers (Total)">
          <div className="grid grid-cols-1 gap-3">
            <BigNumber value="57.3%" label="Social (15–17)" />
            <BigNumber value="35.3%" label="Social (30+)" />
            <BigNumber value="+22.0" label="Δ points (15–17 − 30+)" sub="Primary definition" />
          </div>
        </Panel>

        <div className="text-[10px] text-gray-500">
          Citations to be finalized. CABLAB • Temple University
        </div>
      </div>
    </div>

    <div className="mt-6 pt-4 border-t-4 border-[#9d2235] flex justify-between items-center">
      <p className="text-xs font-bold text-gray-600 uppercase">NCVS incident analyses (survey-weighted)</p>
      <div className="text-gray-400 text-xs">CABLAB</div>
    </div>
  </div>
);

const App = () => {
  return (
    <div className="min-h-screen bg-gray-100 p-8 flex flex-col items-center gap-10">
      <Page1 />
      <div className="hidden print:block" style={{ pageBreakAfter: 'always' }} />
      <Page2 />
      <div className="hidden print:block" style={{ pageBreakAfter: 'always' }} />
      <Page3 />
    </div>
  );
};

export default App;
