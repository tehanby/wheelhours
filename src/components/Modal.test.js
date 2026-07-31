import React from 'react';
import { render, screen } from '@testing-library/react';
import Modal from './Modal';

test('renders modal when isOpen is true', () => {
  render(<Modal isOpen={true}>Content</Modal>);
  expect(screen.getByText('Content')).toBeInTheDocument();
});

test('does not render modal when isOpen is false', () => {
  const { queryByText } = render(<Modal isOpen={false}>Content</Modal>);
  expect(queryByText('Content')).not.toBeInTheDocument();
});
