import React from 'react';
import { Link } from 'react-router-dom';

const Breadcrumb = ({ pathnames }) => {
    return (
        <nav aria-label="breadcrumb">
            <ol className="breadcrumb">
                {pathnames.map((pathname, index) => (
                    <li key={index} className={`breadcrumb-item ${index === pathnames.length - 1 ? 'active' : ''}`}>
                        {index !== pathnames.length - 1 ? (
                            <Link to={pathname.path}>{pathname.label}</Link>
                        ) : (
                            pathname.label
                        )}
                    </li>
                ))}
            </ol>
        </nav>
    );
};

export default Breadcrumb;
