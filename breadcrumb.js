import React from 'react';
import PropTypes from 'prop-types';

const Breadcrumb = ({ items }) => {
  return (
    <nav aria-label="breadcrumb">
      <ol className="breadcrumb">
        {items.map((item, index) => (
          <li key={index} className={`breadcrumb-item ${index === items.length - 1 ? 'active' : ''}`}>
            {item.isLink ? (
              <a href={item.href}>{item.label}</a>
            ) : (
              item.label
            )}
          </li>
        ))}
      </ol>
    </nav>
  );
};

Breadcrumb.propTypes = {
  items: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string.isRequired,
      isLink: PropTypes.bool,
      href: PropTypes.string
    })
  ).isRequired
};

export default Breadcrumb;
