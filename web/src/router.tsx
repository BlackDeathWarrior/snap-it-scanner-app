import { createBrowserRouter } from 'react-router-dom';
import { Layout } from './ui/Layout';
import { CaptureScreen } from './features/capture/CaptureScreen';
import { ResultsScreen } from './features/results/ResultsScreen';
import { HistoryScreen } from './features/history/HistoryScreen';
import { HistoryDetailScreen } from './features/history/HistoryDetailScreen';
import { SettingsScreen } from './features/settings/SettingsScreen';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      { index: true, element: <CaptureScreen /> },
      { path: 'results', element: <ResultsScreen /> },
      { path: 'history', element: <HistoryScreen /> },
      { path: 'history/:id', element: <HistoryDetailScreen /> },
      { path: 'settings', element: <SettingsScreen /> },
    ],
  },
]);
