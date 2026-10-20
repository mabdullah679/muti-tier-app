import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import App from './App';

function mockFetch(routes) {
  global.fetch = jest.fn((url, options) => {
    const handler = routes[`${(options && options.method) || 'GET'} ${url}`];
    if (!handler) return Promise.reject(new Error(`unexpected ${url}`));
    const { status = 200, body } = handler(options);
    return Promise.resolve({ ok: status < 400, status, json: () => Promise.resolve(body) });
  });
}

afterEach(() => {
  delete global.fetch;
});

test('shows backend OK with the serving pod', async () => {
  mockFetch({ 'GET /api/health': () => ({ body: { status: 'ok', servedBy: 'pod-a', uptimeSeconds: 3 } }) });
  render(<App />);
  expect(await screen.findByText(/Backend OK \(served by pod-a\)/)).toBeInTheDocument();
});

test('shows an error state when the backend is down', async () => {
  mockFetch({ 'GET /api/health': () => ({ status: 503, body: { error: 'down' } }) });
  render(<App />);
  expect(await screen.findByText(/Backend unreachable: down/)).toBeInTheDocument();
});

test('submitting the form shows the greeting from the API', async () => {
  mockFetch({
    'GET /api/health': () => ({ body: { status: 'ok', servedBy: 'pod-a' } }),
    'POST /api/greet': (o) => ({ body: { greeting: `Hello, ${JSON.parse(o.body).name}!`, servedBy: 'pod-b' } }),
  });
  render(<App />);
  await userEvent.type(screen.getByLabelText(/your name/i), 'Ada');
  await userEvent.click(screen.getByRole('button', { name: 'Greet' }));
  expect(await screen.findByRole('status')).toHaveTextContent('Hello, Ada!');
});

test('validation errors from the API are shown to the user', async () => {
  mockFetch({
    'GET /api/health': () => ({ body: { status: 'ok', servedBy: 'pod-a' } }),
    'POST /api/greet': () => ({ status: 400, body: { error: '"name" must not be empty' } }),
  });
  render(<App />);
  await userEvent.click(screen.getByRole('button', { name: 'Greet' }));
  await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('"name" must not be empty'));
});
