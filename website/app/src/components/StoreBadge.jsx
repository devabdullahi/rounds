import Icon from './Icon.jsx';

/* The page's one conversion: getting the app. The same badge sits in the hero and the closing
 * section, so wherever a reader stops scrolling, the last action they saw was this one.
 * Until Rounds is live on the App Store, STORE_URL stays null and the badge is a plain
 * "Coming soon" status, not a link. */
export const STORE_URL = null;

function Badge({ live }) {
  return (
    <>
      <Icon name="phone" size={24} />
      <span className="store-text">
        <small>{live ? 'Download on the' : 'Coming soon to the'}</small>
        <b>App Store</b>
      </span>
    </>
  );
}

export default function StoreBadge() {
  if (STORE_URL) {
    return <div className="store-row"><a className="store" href={STORE_URL}><Badge live /></a></div>;
  }
  return <div className="store-row"><span className="store soon"><Badge /></span></div>;
}
