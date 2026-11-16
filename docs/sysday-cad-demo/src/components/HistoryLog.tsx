import type { HistoryEntry } from '../types';

const CAT_ICONS: Record<HistoryEntry['category'], string> = {
  emergency: '🚨',
  dispatch: '🚑',
  arrival: '📍',
  resolved: '✅',
  system: '⚙️',
  rejection: '⛔',
};

function formatTime(ts: number): string {
  return new Date(ts).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

interface Props {
  entries: HistoryEntry[];
}

export default function HistoryLog({ entries }: Props) {
  return (
    <div className="history-wrap">
      <div className="panel-title">📋 Actividad reciente</div>
      <div className="history-scroll">
        {entries.length === 0 && (
          <div className="empty-state">
            <div className="empty-state-icon">📋</div>
            <div>Sin actividad registrada</div>
          </div>
        )}
        {entries.map(entry => (
          <div key={entry.id} className={`history-entry history-entry--${entry.category}`}>
            <span className="history-time">{formatTime(entry.timestamp)}</span>
            <span className="history-icon">{CAT_ICONS[entry.category]}</span>
            <span className="history-msg">{entry.message}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
