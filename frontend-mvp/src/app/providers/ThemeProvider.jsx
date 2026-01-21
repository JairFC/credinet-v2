import { createContext, useContext, useState, useEffect } from 'react';

const ThemeContext = createContext(null);

export const THEMES = {
  dark: 'dark',
  light: 'light'
};

export const ThemeProvider = ({ children }) => {
  // Default to dark theme, check localStorage
  const [theme, setTheme] = useState(() => {
    const saved = localStorage.getItem('credinet-theme');
    return saved || THEMES.dark;
  });

  useEffect(() => {
    // Apply theme to document
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('credinet-theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev === THEMES.dark ? THEMES.light : THEMES.dark);
  };

  const setSpecificTheme = (newTheme) => {
    if (Object.values(THEMES).includes(newTheme)) {
      setTheme(newTheme);
    }
  };

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme, setSpecificTheme, THEMES }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

export default ThemeProvider;
