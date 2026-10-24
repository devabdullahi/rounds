import { renderToString } from 'react-dom/server';
import App from './App.jsx';

/** The page as HTML at build time, so it reads before any script runs (crawlers, link previews). */
export function render() {
  return renderToString(<App />);
}
