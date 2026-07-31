import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import Select from './Select';

test('updates value on select change', () => {
  const handleChange = jest.fn();
  render(<Select onChange={handleChange}>
    <option value="1">Option 1</option>
    <option value="2">Option 2</option>
  </Select>);
  fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
  expect(handleChange).toHaveBeenCalledWith(expect.any(Object));
});
