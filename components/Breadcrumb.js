import React from 'react';

const Breadcrumb = ({ paths }) => {
    return (
        <nav aria-label="breadcrumb">
            <ol className="breadcrumb">
                {paths.map((path, index) => (
                    <li key={index} className={`breadcrumb-item ${index === paths.length - 1 ? 'active' : ''}`}>
                        {index !== paths.length - 1 ? <a href="#">{path}</a> : path}
                    </li>
                ))}
            </ol>
        </nav>
    );
};

export default Breadcrumb;
