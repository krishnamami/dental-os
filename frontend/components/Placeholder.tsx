/**
 * Every route resolves to a real screen from day one.
 *
 * A placeholder that says what the page WILL do is worth more than a
 * blank div: it makes the route graph reviewable before any component
 * exists, and the `endpoint` line records which dental-os call each
 * page is meant to consume, so nobody has to re-derive it later.
 */
import { Link } from "react-router-dom";

import { useDemoLink } from "../hooks/useDemo";

interface Props {
  title: string;
  description: string;
  endpoint?: string;
  audience?: string;
}

export default function Placeholder({
  title,
  description,
  endpoint,
  audience,
}: Props) {
  const demoLink = useDemoLink();
  return (
    <div className="mx-auto max-w-3xl px-6 py-16">
      <p className="text-xs font-semibold uppercase tracking-widest text-accord-green-700">
        Coming soon
      </p>
      <h1 className="mt-2 text-3xl font-semibold text-slate-900">{title}</h1>
      <p className="mt-4 text-slate-600">{description}</p>

      <dl className="mt-8 space-y-3 rounded-lg border border-slate-200 bg-slate-50 p-5 text-sm">
        {audience && (
          <div className="flex gap-3">
            <dt className="w-28 shrink-0 font-medium text-slate-500">Who</dt>
            <dd className="text-slate-700">{audience}</dd>
          </div>
        )}
        {endpoint && (
          <div className="flex gap-3">
            <dt className="w-28 shrink-0 font-medium text-slate-500">Reads</dt>
            <dd className="font-mono text-xs text-slate-700">{endpoint}</dd>
          </div>
        )}
      </dl>

      <Link
        to={demoLink("/")}
        className="mt-8 inline-block text-sm font-medium text-accord-green-700 hover:text-accord-green-900"
      >
        &larr; Back to accorddental.io
      </Link>
    </div>
  );
}
