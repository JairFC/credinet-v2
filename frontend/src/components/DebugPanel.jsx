import React, { useState } from 'react';

const DebugPanel = ({ isVisible = false }) => {
  const [logs, setLogs] = useState([]);

  React.useEffect(() => {
    // Capturar errores
    const originalError = console.error;
    console.error = (...args) => {
      setLogs(prev => [...prev, { type: 'error', message: args.join(' '), time: new Date().toLocaleTimeString() }]);
      originalError(...args);
    };

    // Capturar warnings
    const originalWarn = console.warn;
    console.warn = (...args) => {
      setLogs(prev => [...prev, { type: 'warn', message: args.join(' '), time: new Date().toLocaleTimeString() }]);
      originalWarn(...args);
    };

    // Capturar logs
    const originalLog = console.log;
    console.log = (...args) => {
      setLogs(prev => [...prev, { type: 'log', message: args.join(' '), time: new Date().toLocaleTimeString() }]);
      originalLog(...args);
    };

    return () => {
      console.error = originalError;
      console.warn = originalWarn;
      console.log = originalLog;
    };
  }, []);

  if (!isVisible) return null;

  return (
    <div className="fixed bottom-0 right-0 w-96 h-64 bg-black text-green-400 font-mono text-xs overflow-y-auto z-50 border border-gray-600">
      <div className="p-2 bg-gray-900 text-white flex justify-between">
        <span>Debug Console</span>
        <button
          onClick={() => setLogs([])}
          className="text-red-400 hover:text-red-200"
        >
          Clear
        </button>
      </div>
      <div className="p-2 space-y-1">
        {logs.map((log, index) => (
          <div key={index} className={`
            ${log.type === 'error' ? 'text-red-400' : ''}
            ${log.type === 'warn' ? 'text-yellow-400' : ''}
            ${log.type === 'log' ? 'text-green-400' : ''}
          `}>
            <span className="text-gray-500">[{log.time}]</span> {log.message}
          </div>
        ))}
      </div>
    </div>
  );
};

export default DebugPanel;
