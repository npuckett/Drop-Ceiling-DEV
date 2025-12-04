# GitHub Copilot Instructions

## Project Overview
This is the Drop-Ceiling-DEV project repository. It will be controlling lights connected to a DMX decoder that is connected to this software using an artnet to DMX converter

## Network Details
- router IP: 169.254.166.1
- router subnet: 255.255.0.0
- artnet/DMX node IP: 169.254.166.100

## Resources
- ArtNet Processing Github : https://github.com/cansik/artnet4j
- artnet/dmx node Manual : manuals/cr011r_Manual_book.pdf
- Router : https://www.mokerlink.com/index.php?route=product/product&product_id=381
- DMX Decoder : https://www.amazon.ca/Huaxi-Decoder-Digital-Display-Controller/dp/B07Q1GYLPF/ref=pd_ci_mcx_mh_mcx_views_0_image?pd_rd_w=N24I4&content-id=amzn1.sym.2419cdd9-4822-439a-9284-599ac1726c07%3Aamzn1.symc.c3d5766d-b606-46b8-ab07-1d9d1da0638a&pf_rd_p=2419cdd9-4822-439a-9284-599ac1726c07&pf_rd_r=XEB8J3C4T05K9HEJCPKB&pd_rd_wg=O4aTA&pd_rd_r=7929539c-8cda-4ef6-82c2-ca90ad8039cc&pd_rd_i=B07Q1GYLPF&th=1




## Coding Guidelines
- Code will be written using Processing
- Write clear, self-documenting code with meaningful variable and function names
- Add comments for complex logic or non-obvious implementations
- Keep functions focused and single-purpose
- always put { on the next line to match the braces

## Best Practices
- Test code thoroughly before committing
- Follow existing patterns and conventions in the codebase
- Write maintainable and readable code
- Consider edge cases and error handling

## Documentation
- Update documentation when adding new features
- Include inline comments for complex algorithms
- Document API endpoints and function signatures

## Security
- Never commit sensitive information (API keys, passwords, credentials)
- Follow security best practices for the relevant technologies
- Validate and sanitize user inputs
