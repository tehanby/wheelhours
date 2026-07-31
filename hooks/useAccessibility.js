import React from 'react';

const useAccessibility = (initialProps) => {
  return {
    ...initialProps,
    onClick: (event) => {
      if (initialProps.onClick) initialProps.onClick(event);
      console.log('Element clicked');
    },
  };
};

export default useAccessibility;
